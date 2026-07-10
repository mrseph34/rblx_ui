--!strict
-- Base class every concrete component extends. It owns the lifecycle that all
-- components share so specializations only describe their own structure:
--
--   * Create(parent, props) — subclasses override _Build to add GuiObjects.
--   * ApplyTheme(theme)     — subclasses override _Style to paint tokens.
--   * PlayAnimation(name)   — a shared animation library (Appear/Disappear/
--                             HoverOn/HoverOff/Press/Release/Pulse) driven by
--                             the active theme's TweenInfos and effect scales.
--   * Destroy()             — cancels tweens, drops connections, unregisters
--                             from the theme controller, destroys instances.
--
-- Components auto-register with UIThemeController on Create and get ApplyTheme
-- called again on every live theme swap — that is what makes the whole UI
-- re-skin (and the in-game editor's live preview) work with no per-component
-- wiring. Registration is injected (SetThemeController) to avoid a require
-- cycle between components and the controller.

local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local UISignal = require(script.Parent.Parent.UISignal)

local UIComponentBase = {}
UIComponentBase.__index = UIComponentBase

-- Injected once at boot by the ClientHandler. Nil-safe so components can be
-- built in isolation (e.g. unit/smoke tests) without a controller present.
local themeController: any = nil
function UIComponentBase.SetThemeController(controller: any)
	themeController = controller
end

export type Component = typeof(setmetatable(
	{} :: {
		Root: GuiObject,
		Props: Types.UIComponentProps,
		Theme: Types.UITheme?,
		Destroyed: typeof(UISignal.new()),
		_connections: { RBXScriptConnection },
		_tweens: { Tween },
		_baseSize: UDim2,
		_themeRegistration: any,
	},
	UIComponentBase
))

-- Subclasses call this from their own .new to get a configured instance, then
-- override _Build/_Style. `className` names the root frame for debugging.
function UIComponentBase.new(className: string): Component
	local self = setmetatable({}, UIComponentBase)
	self.Props = {}
	self.Theme = nil
	self.Destroyed = UISignal.new()
	self._connections = {}
	self._tweens = {}
	self._styledOnce = false
	self._baseSize = UDim2.fromScale(1, 1)
	self.Root = UIStyler.Frame(className)
	self.Root.BackgroundTransparency = 1
	return self :: any
end

-- ---- lifecycle ---------------------------------------------------------

function UIComponentBase:Create(parent: Instance?, props: Types.UIComponentProps?): GuiObject
	if props then
		self.Props = props
	end
	local p = self.Props

	if p.size then
		self.Root.Size = p.size
	end
	self._baseSize = self.Root.Size
	if p.position then
		self.Root.Position = p.position
	end
	if p.anchorPoint then
		self.Root.AnchorPoint = p.anchorPoint
	end
	if p.layoutOrder then
		self.Root.LayoutOrder = p.layoutOrder
	end

	-- Subclass builds its inner GuiObjects.
	self:_Build(p)

	if parent then
		self.Root.Parent = parent
	end

	-- Subscribe to live theme changes; apply the current theme immediately.
	if themeController then
		self._themeRegistration = themeController:RegisterComponent(self)
		self:ApplyTheme(themeController:GetTheme())
	end

	return self.Root
end

-- Override in subclasses. Default is a no-op container.
function UIComponentBase:_Build(_props: Types.UIComponentProps) end

-- Override in subclasses to paint theme tokens onto instances built in _Build.
function UIComponentBase:_Style(_theme: Types.UITheme) end

function UIComponentBase:ApplyTheme(theme: Types.UITheme?)
	if not theme then
		return
	end
	self.Theme = theme
	self:_Style(theme)
	-- After the first paint, later theme changes are allowed to cross-fade.
	self._styledOnce = true
end

-- Apply a color to a property. The FIRST time a component is themed we set it
-- directly so the correct color is guaranteed to land even if a tween is later
-- interrupted; subsequent theme swaps cross-fade for the polished feel. This is
-- why components never tween color straight from the default white.
function UIComponentBase:_SetColor(instance: Instance, prop: string, color: Color3)
	if self._styledOnce and self.Theme then
		self:_Tween(instance, self.Theme.Animations.ThemeSwap, { [prop] = color })
	else
		(instance :: any)[prop] = color
	end
end

-- ---- shared animation library -----------------------------------------

-- Named animations resolve to theme TweenInfos + effect scales so the same
-- call ("HoverOn") feels different per theme without component changes.
function UIComponentBase:PlayAnimation(name: string)
	local theme = self.Theme
	if not theme then
		return
	end
	local anims = theme.Animations
	local effects = theme.Effects
	local root = self.Root

	if name == "Appear" then
		-- Scale-pop only. We deliberately do NOT animate descendant transparency:
		-- doing so would fight the themed transparency values (shadows, strokes)
		-- and, if interrupted, leave the whole component translucent/grey.
		root.Visible = true
		root.Size = self:_ScaledSize(0.9)
		self:_Tween(root, anims.Appear, { Size = self._baseSize })
	elseif name == "Disappear" then
		self:_Tween(root, anims.Disappear, { Size = self:_ScaledSize(0.9) })
	elseif name == "HoverOn" then
		self:_Tween(root, anims.Hover, { Size = self:_ScaledSize(effects.HoverScale) })
	elseif name == "HoverOff" then
		self:_Tween(root, anims.Hover, { Size = self._baseSize })
	elseif name == "Press" then
		self:_Tween(root, anims.Press, { Size = self:_ScaledSize(effects.PressScale) })
	elseif name == "Release" then
		self:_Tween(root, anims.Hover, { Size = self:_ScaledSize(effects.HoverScale) })
	elseif name == "Pulse" then
		local pulse = self:_Tween(root, anims.Emphasis, { Size = self:_ScaledSize(effects.HoverScale + 0.06) })
		pulse.Completed:Once(function()
			if root.Parent then
				self:_Tween(root, anims.Emphasis, { Size = self._baseSize })
			end
		end)
	end
end

-- Scale a UDim2 about its center by multiplying its offset+scale magnitudes.
function UIComponentBase:_ScaledSize(factor: number): UDim2
	local base = self._baseSize
	return UDim2.new(
		base.X.Scale * factor,
		base.X.Offset * factor,
		base.Y.Scale * factor,
		base.Y.Offset * factor
	)
end

-- ---- tween / transparency helpers -------------------------------------

function UIComponentBase:_Tween(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tween = UIStyler.Tween(instance, info, goal)
	table.insert(self._tweens, tween)
	return tween
end

-- ---- connection bookkeeping -------------------------------------------

function UIComponentBase:_Connect(event: RBXScriptSignal, handler: (...any) -> ())
	table.insert(self._connections, event:Connect(handler))
end

-- Wire the universal hover/press feel + click callback onto any GuiButton.
function UIComponentBase:_BindInteractions(button: GuiButton)
	self:_Connect(button.MouseEnter, function()
		if self.Props.enabled ~= false then
			self:PlayAnimation("HoverOn")
		end
	end)
	self:_Connect(button.MouseLeave, function()
		self:PlayAnimation("HoverOff")
	end)
	self:_Connect(button.MouseButton1Down, function()
		if self.Props.enabled ~= false then
			self:PlayAnimation("Press")
		end
	end)
	self:_Connect(button.MouseButton1Up, function()
		if self.Props.enabled ~= false then
			self:PlayAnimation("Release")
		end
	end)
	self:_Connect(button.Activated, function()
		if self.Props.enabled ~= false and self.Props.onClick then
			self.Props.onClick()
		end
	end)
end

function UIComponentBase:Destroy()
	for _, tween in self._tweens do
		tween:Cancel()
	end
	table.clear(self._tweens)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	if self._themeRegistration then
		self._themeRegistration:Disconnect()
		self._themeRegistration = nil
	end
	self.Destroyed:Fire()
	self.Destroyed:Clear()
	if self.Root then
		self.Root:Destroy()
	end
end

return UIComponentBase

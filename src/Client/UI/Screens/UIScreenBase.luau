--!strict
-- Base class for screens. Each screen owns exactly one ScreenGui built via
-- script; the base handles construction, the show/hide fade, controller
-- injection and teardown. Subclasses override _BuildContent (populate the root)
-- and optionally _OnShow/_OnHide/Update.
--
-- Screens receive the theme + screen controllers via SetControllers, so they
-- can read the active theme/pack and (for interactive screens) drive
-- navigation without global singletons.

local Players = game:GetService("Players")

local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)

local UIScreenBase = {}
UIScreenBase.__index = UIScreenBase

-- Optional sound controller injected at boot; screens play Success/Error etc.
local soundController: any = nil
function UIScreenBase.SetSoundController(controller: any)
	soundController = controller
end

function UIScreenBase:_PlaySound(event: string)
	if soundController then
		soundController:Play(event)
	end
end

function UIScreenBase.new(name: string, displayOrder: number?)
	local self = setmetatable({}, UIScreenBase)
	self.Name = name
	self.ThemeController = nil :: any
	self.ScreenController = nil :: any
	self._built = false
	self._visible = false
	-- Raw (non-component) labels this screen wants kept in sync with the theme.
	self._themedLabels = {} :: { { label: TextLabel, colorToken: string, fontToken: string } }

	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = displayOrder or 1
	gui.Enabled = false
	self.Gui = gui

	-- Full-screen transparent root every screen parents content into.
	local root = UIStyler.Frame("Root")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	self.Root = root

	return self
end

-- A screen with a main UIPanelComponent registers it here so the base can drive
-- a consistent intro on show and a REVERSE outro on hide (the panel leaves the
-- way it came), instead of the old instant fade-out. The panel's animation pack
-- (grow/slide/…) is chosen globally in PanelAnimConfig.
function UIScreenBase:_SetAnimatedPanel(panel: any)
	self._animatedPanel = panel
end

function UIScreenBase:SetControllers(themeController: any, screenController: any)
	self.ThemeController = themeController
	self.ScreenController = screenController
	-- Keep raw labels in sync when the theme changes live (editor previews).
	themeController.ThemeChanged:Connect(function()
		self:_RepaintLabels()
	end)
end

-- Resolve a text key (or pass-through literal).
function UIScreenBase:_R(keyOrText: string?): string
	return TextConfig.Resolve(keyOrText)
end

-- Create a raw TextLabel wired to theme tokens and registered for repaint on
-- live theme changes. Use for section headers and other non-component text.
function UIScreenBase:_ScreenLabel(parent: Instance, text: string, colorToken: string, fontToken: string, layoutOrder: number?): TextLabel
	local label = UIStyler.TextLabel("Label")
	label.Size = UDim2.new(1, 0, 0, 26)
	label.Text = text
	label.TextXAlignment = Enum.TextXAlignment.Left
	if layoutOrder then
		label.LayoutOrder = layoutOrder
	end
	label.Parent = parent
	table.insert(self._themedLabels, { label = label, colorToken = colorToken, fontToken = fontToken })
	self:_PaintLabel(label, colorToken, fontToken)
	return label
end

function UIScreenBase:_PaintLabel(label: TextLabel, colorToken: string, fontToken: string)
	local theme = self:GetTheme()
	label.TextColor3 = (theme.Colors :: any)[colorToken] or theme.Colors.TextPrimary
	label.FontFace = (theme.Fonts :: any)[fontToken] or theme.Fonts.Body
	label.TextSize = (theme.TextSizes :: any)[fontToken] or theme.TextSizes.Body
	-- Match component text: apply the theme's optional outline to raw section
	-- labels too (theme-gated; disabled cleanly for themes without one).
	UIStyler.ApplyThemeOutline(label, theme.TextOutline)
end

function UIScreenBase:_RepaintLabels()
	-- Drop destroyed labels lazily while repainting the live ones.
	for i = #self._themedLabels, 1, -1 do
		local entry = self._themedLabels[i]
		if entry.label.Parent then
			self:_PaintLabel(entry.label, entry.colorToken, entry.fontToken)
		else
			table.remove(self._themedLabels, i)
		end
	end
end

function UIScreenBase:_EnsureBuilt()
	if self._built then
		return
	end
	self._built = true
	-- Parent to the local player's PlayerGui lazily (first show), so screens
	-- can be constructed before the GUI hierarchy is needed.
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		self.Gui.Parent = playerGui
	end
	self:_BuildContent()
end

-- Override: build content into self.Root using components.
function UIScreenBase:_BuildContent() end

-- Override: react to show/hide (start timers, refresh data).
function UIScreenBase:_OnShow(_data: any?) end
function UIScreenBase:_OnHide() end

function UIScreenBase:GetTheme(): Types.UITheme
	return self.ThemeController:GetTheme()
end

function UIScreenBase:Show(data: any?)
	self:_EnsureBuilt()
	self._visible = true
	self.Gui.Enabled = true
	local theme = self:GetTheme()
	self.Root.Size = UDim2.fromScale(1, 1)
	-- Fade the root in; individual components animate themselves on build.
	UIStyler.Tween(self.Root, theme.Animations.Appear, { BackgroundTransparency = 1 })
	self:_OnShow(data)
	-- Drive the registered panel's intro centrally (grow/slide per the active
	-- animation pack). Screens no longer call PlayAnimation("Appear") themselves.
	if self._animatedPanel then
		self._animatedPanel:AnimateIn()
	end
end

function UIScreenBase:Hide()
	if not self._visible then
		return
	end
	self._visible = false
	self:_OnHide()
	local theme = self:GetTheme()
	-- If this screen has an animated panel, play its outro (reverse of the intro)
	-- and only disable the Gui once that exit finishes — so the panel visibly
	-- leaves (shrinks/slides back out) instead of just blinking off.
	if self._animatedPanel then
		local out = self._animatedPanel:AnimateOut()
		UIStyler.Tween(self.Root, theme.Animations.Disappear, { BackgroundTransparency = 1 })
		if out then
			out.Completed:Once(function()
				if not self._visible then
					self.Gui.Enabled = false
				end
			end)
			return
		end
	end
	local fade = UIStyler.Tween(self.Root, theme.Animations.Disappear, { BackgroundTransparency = 1 })
	fade.Completed:Once(function()
		if not self._visible then
			self.Gui.Enabled = false
		end
	end)
end

function UIScreenBase:Update(_data: any) end

function UIScreenBase:IsVisible(): boolean
	return self._visible
end

function UIScreenBase:Destroy()
	if self.Gui then
		self.Gui:Destroy()
	end
end

return UIScreenBase

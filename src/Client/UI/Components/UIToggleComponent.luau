--!strict
-- Animated on/off switch with a sliding knob — the Settings-style toggle from
-- the reference art. Emits changes via onChanged.
--
-- Extra props:
--   labelKey / label
--   value     : boolean initial state
--   onChanged : (value: boolean) -> ()

local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local UIComponentBase = require(script.Parent.UIComponentBase)

local UIToggleComponent = setmetatable({}, { __index = UIComponentBase })
UIToggleComponent.__index = UIToggleComponent

function UIToggleComponent.new()
	local self = UIComponentBase.new("UIToggle")
	self._value = false
	return setmetatable(self, UIToggleComponent)
end

function UIToggleComponent:_Build(props: Types.UIComponentProps)
	self._value = props.value == true
	local root = self.Root
	root.BackgroundTransparency = 1
	if not props.size then
		root.Size = UDim2.new(1, 0, 0, 36)
		self._baseSize = root.Size
	end

	local label = UIStyler.TextLabel("Label")
	label.Size = UDim2.new(0.78, 0, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextScaled = true
	self._labelConstraint = UIStyler.TextSizeConstraint(16, 8)
	self._labelConstraint.Parent = label
	label.Text = TextConfig.Resolve(props.labelKey or props.label)
	label.Parent = root
	self._label = label

	-- Track/Knob are Scale fractions of Root (never a fixed pixel Offset), so
	-- they scale consistently if Root's own height/width ever changes instead
	-- of staying a hardcoded size regardless of context. Each also gets its
	-- own AspectRatioConstraint (Track 2:1, Knob a perfect 1:1 circle) so
	-- they hold their real shape regardless of Root's actual resolved width
	-- — a plain Scale size alone can't guarantee that since Root's width and
	-- height don't share a fixed ratio. Starting sizes are non-zero on both
	-- axes (never Scale=0) — an AspectRatioConstraint driving a Scale=0
	-- starting dimension collapses to 0x0 instead of resolving correctly.
	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.Text = ""
	track.AutoButtonColor = false
	track.Size = UDim2.fromScale(0.22, 0.78)
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, 0, 0.5, 0)
	UIStyler.AspectRatio(2, Enum.DominantAxis.Height).Parent = track
	UIStyler.Corner(1000).Parent = track
	track.Parent = root
	self._track = track

	local knob = UIStyler.Frame("Knob")
	knob.Size = UDim2.fromScale(0.39, 0.78)
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Position = UDim2.new(0.06, 0, 0.5, 0)
	UIStyler.AspectRatio(1, Enum.DominantAxis.Height).Parent = knob
	UIStyler.Corner(1000).Parent = knob
	knob.Parent = track
	self._knob = knob

	self:_Connect(track.Activated, function()
		self:Set(not self._value, true)
	end)
end

function UIToggleComponent:Set(value: boolean, notify: boolean?)
	self._value = value
	if self.Theme then
		local anims = self.Theme.Animations
		-- Pure Scale positions (fractions of Track's own width), matching the
		-- same 0.06 margin used on both sides in _Build.
		local onPos = UDim2.new(0.55, 0, 0.5, 0)
		local offPos = UDim2.new(0.06, 0, 0.5, 0)
		self:_Tween(self._knob, anims.Emphasis, { Position = value and onPos or offPos })
		self:_Tween(self._track, anims.Emphasis, {
			BackgroundColor3 = value and self.Theme.Colors.Success or self.Theme.Colors.Disabled,
		})
	end
	if notify and self.Props.onChanged then
		self.Props.onChanged(value)
	end
end

function UIToggleComponent:GetValue(): boolean
	return self._value
end

function UIToggleComponent:_Style(theme: Types.UITheme)
	local c = theme.Colors
	self._label.FontFace = theme.Fonts.Body
	self._label.TextColor3 = c.TextPrimary
	if self._labelConstraint then
		self._labelConstraint.MaxTextSize = theme.TextSizes.Body
	end
	self._knob.BackgroundColor3 = c.TextOnPrimary
	self._track.BackgroundColor3 = self._value and c.Success or c.Disabled
	self._knob.Position = self._value and UDim2.new(0.55, 0, 0.5, 0) or UDim2.new(0.06, 0, 0.5, 0)
end

return UIToggleComponent

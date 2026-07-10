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
	label.Size = UDim2.new(1, -70, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = TextConfig.Resolve(props.labelKey or props.label)
	label.Parent = root
	self._label = label

	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.Text = ""
	track.AutoButtonColor = false
	track.Size = UDim2.fromOffset(56, 28)
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, 0, 0.5, 0)
	UIStyler.Corner(1000).Parent = track
	track.Parent = root
	self._track = track

	local knob = UIStyler.Frame("Knob")
	knob.Size = UDim2.fromOffset(22, 22)
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Position = UDim2.new(0, 3, 0.5, 0)
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
		local onPos = UDim2.new(1, -25, 0.5, 0)
		local offPos = UDim2.new(0, 3, 0.5, 0)
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
	self._label.TextSize = theme.TextSizes.Body
	self._label.TextColor3 = c.TextPrimary
	self._knob.BackgroundColor3 = c.TextOnPrimary
	self._track.BackgroundColor3 = self._value and c.Success or c.Disabled
	self._knob.Position = self._value and UDim2.new(1, -25, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
end

return UIToggleComponent

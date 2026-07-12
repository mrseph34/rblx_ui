--!strict
-- Draggable value slider used throughout the Theme Editor for numeric tokens
-- (radii, spacing, animation time, effect scales). Reports live value via
-- onChanged as the user drags — this is what powers real-time theme preview.
--
-- Extra props:
--   labelKey / label
--   min, max  : number range (default 0..1)
--   step      : optional snap increment
--   value     : initial value
--   decimals  : digits shown in the value readout (default 2)
--   onChanged : (value: number) -> ()

local UserInputService = game:GetService("UserInputService")

local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local UIComponentBase = require(script.Parent.UIComponentBase)

local UISliderComponent = setmetatable({}, { __index = UIComponentBase })
UISliderComponent.__index = UISliderComponent

function UISliderComponent.new()
	local self = UIComponentBase.new("UISlider")
	self._value = 0
	self._dragging = false
	return setmetatable(self, UISliderComponent)
end

function UISliderComponent:_Build(props: Types.UIComponentProps)
	self._min = props.min or 0
	self._max = props.max or 1
	self._step = props.step
	self._decimals = props.decimals or 2
	self._value = math.clamp(props.value or self._min, self._min, self._max)

	-- Compact = single row (label · track · value), for dense controls like the
	-- color channel editors. Stacked = header row over a full-width track, for
	-- the wider numeric-token sliders. One component, two layouts, so the two
	-- never drift apart. (The color field used to give a stacked slider only
	-- 20px, pushing its y=30 track out of view — that's what broke the R row.)
	self._compact = props.compact == true
	local root = self.Root
	root.BackgroundTransparency = 1
	if not props.size then
		root.Size = UDim2.new(1, 0, 0, self._compact and 22 or 44)
		self._baseSize = root.Size
	end

	-- Pure Scale fractions of Root (never a fixed pixel Offset) — labelWidth
	-- is 0 for the stacked (non-compact) layout since its label fills
	-- whatever's left after the value readout.
	local labelWidthFrac = self._compact and 0.16 or 0
	local valueWidthFrac = self._compact and 0.24 or 0.22

	local label = UIStyler.TextLabel("Label")
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextScaled = true
	self._labelConstraint = UIStyler.TextSizeConstraint(14, 7)
	self._labelConstraint.Parent = label
	label.Text = TextConfig.Resolve(props.labelKey or props.label)
	self._label = label

	local readout = UIStyler.TextLabel("Value")
	readout.TextXAlignment = Enum.TextXAlignment.Right
	readout.TextScaled = true
	self._readoutConstraint = UIStyler.TextSizeConstraint(14, 7)
	self._readoutConstraint.Parent = readout
	self._readout = readout

	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.Text = ""
	track.AutoButtonColor = false
	UIStyler.Corner(1000).Parent = track
	self._track = track

	if self._compact then
		-- One row: label (left) | track (fills middle) | value (right).
		label.Size = UDim2.fromScale(labelWidthFrac, 1)
		label.Position = UDim2.fromScale(0, 0)
		label.Parent = root
		readout.Size = UDim2.fromScale(valueWidthFrac, 1)
		readout.AnchorPoint = Vector2.new(1, 0)
		readout.Position = UDim2.fromScale(1, 0)
		readout.Parent = root
		track.Size = UDim2.new(1 - labelWidthFrac - valueWidthFrac - 0.06, 0, 0.27, 0)
		track.Position = UDim2.new(labelWidthFrac + 0.03, 0, 0.5, 0)
		track.AnchorPoint = Vector2.new(0, 0.5)
		track.Parent = root
	else
		-- Header row (label + value) stacked over a full-width track.
		local header = UIStyler.Frame("Header")
		header.BackgroundTransparency = 1
		header.Size = UDim2.new(1, 0, 0.4, 0)
		header.Parent = root
		label.Size = UDim2.new(1 - valueWidthFrac, 0, 1, 0)
		label.Parent = header
		readout.Size = UDim2.fromScale(valueWidthFrac, 1)
		readout.AnchorPoint = Vector2.new(1, 0)
		readout.Position = UDim2.fromScale(1, 0)
		readout.Parent = header
		track.Size = UDim2.new(1, 0, 0.18, 0)
		track.Position = UDim2.new(0, 0, 0.68, 0)
		track.Parent = root
	end

	local fill = UIStyler.Frame("Fill")
	fill.Size = UDim2.fromScale(0, 1)
	UIStyler.Corner(1000).Parent = fill
	fill.Parent = track
	self._fill = fill

	-- Knob is a perfect circle (AspectRatioConstraint 1:1, DominantAxis
	-- Height) sized as a Scale fraction of the track's own height instead of
	-- a fixed pixel Offset, so it always renders round regardless of the
	-- track's real resolved thickness. Starting size is non-zero on both
	-- axes (never Scale=0) — an AspectRatioConstraint driving a Scale=0
	-- starting dimension collapses to 0x0 instead of resolving correctly.
	local knob = UIStyler.Frame("Knob")
	knob.Size = UDim2.fromScale(2.2, 2.2)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0, 0.5)
	UIStyler.AspectRatio(1, Enum.DominantAxis.Height).Parent = knob
	UIStyler.Corner(1000).Parent = knob
	knob.Parent = track
	self._knob = knob

	self:_Connect(track.MouseButton1Down, function()
		self._dragging = true
		self:_UpdateFromInput()
	end)
	self:_Connect(UserInputService.InputEnded, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._dragging = false
		end
	end)
	self:_Connect(UserInputService.InputChanged, function(input: InputObject)
		if self._dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			self:_UpdateFromInput()
		end
	end)

	self:_Render()
end

function UISliderComponent:_UpdateFromInput()
	local mouse = UserInputService:GetMouseLocation()
	local absPos = self._track.AbsolutePosition.X
	local absSize = self._track.AbsoluteSize.X
	local alpha = absSize > 0 and math.clamp((mouse.X - absPos) / absSize, 0, 1) or 0
	self:Set(self._min + alpha * (self._max - self._min), true)
end

function UISliderComponent:Set(value: number, notify: boolean?)
	if self._step then
		value = math.floor(value / self._step + 0.5) * self._step
	end
	value = math.clamp(value, self._min, self._max)
	self._value = value
	self:_Render()
	if notify and self.Props.onChanged then
		self.Props.onChanged(value)
	end
end

function UISliderComponent:GetValue(): number
	return self._value
end

function UISliderComponent:_Render()
	local alpha = (self._max - self._min) > 0 and (self._value - self._min) / (self._max - self._min) or 0
	self._fill.Size = UDim2.fromScale(alpha, 1)
	self._knob.Position = UDim2.fromScale(alpha, 0.5)
	self._readout.Text = string.format("%." .. self._decimals .. "f", self._value)
end

function UISliderComponent:_Style(theme: Types.UITheme)
	local c = theme.Colors
	self._label.FontFace = theme.Fonts.Body
	self._label.TextColor3 = c.TextSecondary
	if self._labelConstraint then
		self._labelConstraint.MaxTextSize = theme.TextSizes.Small
	end
	self._readout.FontFace = theme.Fonts.Numeric
	self._readout.TextColor3 = c.TextPrimary
	if self._readoutConstraint then
		self._readoutConstraint.MaxTextSize = theme.TextSizes.Small
	end
	self._track.BackgroundColor3 = c.Surface
	self._fill.BackgroundColor3 = c.Primary
	self._knob.BackgroundColor3 = c.TextOnPrimary
end

return UISliderComponent

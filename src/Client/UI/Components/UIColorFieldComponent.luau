--!strict
-- RGB color editor row: a name, a live swatch, and three sliders. This is the
-- per-color control the Theme Editor stacks for every color token. Reports the
-- composed Color3 via onChanged on every slider move, driving live re-theming.
--
-- Extra props:
--   label     : token display name
--   value     : Color3 initial
--   onChanged : (color: Color3) -> ()

local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local UIComponentBase = require(script.Parent.UIComponentBase)
local UISliderComponent = require(script.Parent.UISliderComponent)

local UIColorFieldComponent = setmetatable({}, { __index = UIComponentBase })
UIColorFieldComponent.__index = UIColorFieldComponent

function UIColorFieldComponent.new()
	local self = UIComponentBase.new("UIColorField")
	self._sliders = {}
	return setmetatable(self, UIColorFieldComponent)
end

function UIColorFieldComponent:_Build(props: Types.UIComponentProps)
	local color = (props.value :: Color3?) or Color3.new(1, 1, 1)
	self._color = color

	local root = self.Root
	root.BackgroundTransparency = 0
	if not props.size then
		root.Size = UDim2.new(1, 0, 0, 92)
		self._baseSize = root.Size
	end
	self._corner = UIStyler.Corner(10)
	self._corner.Parent = root
	UIStyler.Padding(8).Parent = root

	local header = UIStyler.Frame("Header")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0.28, 0)
	header.Parent = root

	-- Swatch is a perfect square (AspectRatioConstraint 1:1, DominantAxis
	-- Height) instead of a fixed pixel Offset, so it scales with the header's
	-- real resolved height. Starting size is non-zero on both axes (never
	-- Scale=0) — an AspectRatioConstraint driving a Scale=0 starting
	-- dimension collapses to 0x0 instead of resolving correctly.
	local swatch = UIStyler.Frame("Swatch")
	swatch.Size = UDim2.fromScale(0.3, 1)
	UIStyler.AspectRatio(1, Enum.DominantAxis.Height).Parent = swatch
	swatch.BackgroundColor3 = color
	UIStyler.Corner(6).Parent = swatch
	UIStyler.Stroke(Color3.new(0, 0, 0), 1, 0.5).Parent = swatch
	swatch.Parent = header
	self._swatch = swatch

	local name = UIStyler.TextLabel("Name")
	name.Size = UDim2.fromScale(0.84, 1)
	name.Position = UDim2.fromScale(0.16, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextScaled = true
	self._nameConstraint = UIStyler.TextSizeConstraint(16, 8)
	self._nameConstraint.Parent = name
	name.Text = props.label or "Color"
	name.Parent = header
	self._name = name

	-- Three channel sliders laid out below the header.
	local sliderHolder = UIStyler.Frame("Channels")
	sliderHolder.BackgroundTransparency = 1
	sliderHolder.Size = UDim2.new(1, 0, 0.72, 0)
	sliderHolder.Position = UDim2.new(0, 0, 0.28, 0)
	UIStyler.ListLayout({ Padding = UDim.new(0, 2) }).Parent = sliderHolder
	sliderHolder.Parent = root

	local channels = { "R", "G", "B" }
	local components = { color.R * 255, color.G * 255, color.B * 255 }
	for i, channel in channels do
		local slider = UISliderComponent.new()
		slider:Create(sliderHolder, {
			label = channel,
			compact = true,
			min = 0,
			max = 255,
			step = 1,
			decimals = 0,
			value = math.round(components[i]),
			layoutOrder = i,
			size = UDim2.new(1, 0, 0, 20),
			onChanged = function()
				self:_Recompose()
			end,
		})
		self._sliders[channel] = slider
	end
end

function UIColorFieldComponent:_Recompose()
	local r = self._sliders.R:GetValue() / 255
	local g = self._sliders.G:GetValue() / 255
	local b = self._sliders.B:GetValue() / 255
	self._color = Color3.new(r, g, b)
	self._swatch.BackgroundColor3 = self._color
	if self.Props.onChanged then
		self.Props.onChanged(self._color)
	end
end

function UIColorFieldComponent:GetColor(): Color3
	return self._color
end

function UIColorFieldComponent:_Style(theme: Types.UITheme)
	local c = theme.Colors
	self.Root.BackgroundColor3 = c.Surface
	self._corner.CornerRadius = UDim.new(0, theme.Radii.Small)
	self._name.FontFace = theme.Fonts.Subtitle
	self._name.TextColor3 = c.TextPrimary
	if self._nameConstraint then
		self._nameConstraint.MaxTextSize = theme.TextSizes.Body
	end
end

function UIColorFieldComponent:Destroy()
	for _, slider in self._sliders do
		slider:Destroy()
	end
	UIComponentBase.Destroy(self)
end

return UIColorFieldComponent

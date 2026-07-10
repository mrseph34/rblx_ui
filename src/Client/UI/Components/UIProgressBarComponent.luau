--!strict
-- Fillable bar used by the HUD (health, XP) and progress indicators. Fill
-- tweens with the theme's Emphasis easing so value changes feel alive.
--
-- Extra props:
--   value, maxValue : numbers (default 0..100)
--   colorToken      : theme color token name for the fill (default "Success")
--   showText        : boolean, overlay "value/max"

local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local UIComponentBase = require(script.Parent.UIComponentBase)

local UIProgressBarComponent = setmetatable({}, { __index = UIComponentBase })
UIProgressBarComponent.__index = UIProgressBarComponent

function UIProgressBarComponent.new()
	local self = UIComponentBase.new("UIProgressBar")
	self._value = 0
	self._max = 100
	return setmetatable(self, UIProgressBarComponent)
end

function UIProgressBarComponent:_Build(props: Types.UIComponentProps)
	self._value = props.value or 0
	self._max = props.maxValue or 100
	self._colorToken = props.colorToken or "Success"

	local root = self.Root
	root.BackgroundTransparency = 0
	if not props.size then
		root.Size = UDim2.new(1, 0, 0, 18)
		self._baseSize = root.Size
	end
	self._corner = UIStyler.Corner(1000)
	self._corner.Parent = root

	local fill = UIStyler.Frame("Fill")
	fill.Size = UDim2.fromScale(0, 1)
	UIStyler.Corner(1000).Parent = fill
	self._fillGradient = UIStyler.Gradient(0, 0.12)
	self._fillGradient.Parent = fill
	fill.Parent = root
	self._fill = fill

	if props.showText then
		local text = UIStyler.TextLabel("Text")
		text.Size = UDim2.fromScale(1, 1)
		text.ZIndex = 2
		text.Parent = root
		self._text = text
	end

	self:_Render(false)
end

function UIProgressBarComponent:Set(value: number, maxValue: number?)
	self._value = value
	if maxValue then
		self._max = maxValue
	end
	self:_Render(true)
end

function UIProgressBarComponent:_Render(animate: boolean)
	local alpha = self._max > 0 and math.clamp(self._value / self._max, 0, 1) or 0
	if animate and self.Theme then
		self:_Tween(self._fill, self.Theme.Animations.Emphasis, { Size = UDim2.fromScale(alpha, 1) })
	else
		self._fill.Size = UDim2.fromScale(alpha, 1)
	end
	if self._text then
		self._text.Text = string.format("%d / %d", math.floor(self._value), math.floor(self._max))
	end
end

function UIProgressBarComponent:_Style(theme: Types.UITheme)
	local c = theme.Colors
	self.Root.BackgroundColor3 = c.Surface
	self._corner.CornerRadius = UDim.new(0, theme.Radii.Pill)
	self._fill.BackgroundColor3 = (c :: any)[self._colorToken] or c.Success
	self._fillGradient.Enabled = theme.Effects.UseGradients
	if self._text then
		self._text.FontFace = theme.Fonts.Numeric
		self._text.TextSize = theme.TextSizes.Small
		self._text.TextColor3 = c.TextOnPrimary
	end
end

return UIProgressBarComponent

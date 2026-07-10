--!strict
-- Themed text/icon button with hover/press motion, variants and a disabled
-- state. Extends UIComponentBase, overriding only _Build and _Style.
--
-- Extra props:
--   variant : "Primary" | "Secondary" | "Accent" | "Ghost" | "Danger" | "Success"
--   text / textKey, icon (emoji), iconId (image)
--   enabled : false to disable (dimmed, non-interactive)

local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local UIComponentBase = require(script.Parent.UIComponentBase)

local UIButtonComponent = setmetatable({}, { __index = UIComponentBase })
UIButtonComponent.__index = UIButtonComponent

function UIButtonComponent.new()
	local self = UIComponentBase.new("UIButton")
	return setmetatable(self, UIButtonComponent)
end

function UIButtonComponent:_Build(props: Types.UIComponentProps)
	local root = self.Root
	root.BackgroundTransparency = 0
	if not props.size then
		root.Size = UDim2.new(0, 180, 0, 48)
		self._baseSize = root.Size
	end

	local button = Instance.new("TextButton")
	button.Name = "Hit"
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromScale(1, 1)
	button.Text = ""
	button.AutoButtonColor = false
	button.Parent = root
	self._button = button

	self._corner = UIStyler.Corner(10)
	self._corner.Parent = root
	self._stroke = UIStyler.Stroke(Color3.new(), 1.5)
	self._stroke.Parent = root
	self._gradient = UIStyler.Gradient(90, 0.12)
	self._gradient.Parent = root

	local layout = UIStyler.ListLayout({
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
	})
	layout.Parent = root

	local icon = UIStyler.TextLabel("Icon")
	icon.Size = UDim2.fromOffset(24, 24)
	icon.TextScaled = true
	icon.LayoutOrder = 1
	icon.Visible = false
	icon.Parent = root
	self._icon = icon

	local label = UIStyler.TextLabel("Label")
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.LayoutOrder = 2
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = root
	self._label = label

	self:_BindInteractions(button)
	self:SetContent(props)
end

-- Update text/icon after construction without rebuilding.
function UIButtonComponent:SetContent(props: Types.UIComponentProps)
	local text = TextConfig.Resolve(props.textKey or props.text)
	self._label.Text = text
	self._label.Visible = text ~= ""
	if props.icon then
		self._icon.Text = props.icon
		self._icon.Visible = true
	elseif props.iconId then
		-- Swap the emoji label for an image if an asset id is given later.
		self._icon.Text = ""
		self._icon.Visible = true
	else
		self._icon.Visible = false
	end
end

function UIButtonComponent:SetEnabled(enabled: boolean)
	self.Props.enabled = enabled
	if self.Theme then
		self:_Style(self.Theme)
	end
end

-- Resolve the fill/text colors for the current variant + enabled state.
function UIButtonComponent:_VariantColors(theme: Types.UITheme): (Color3, Color3, boolean)
	local c = theme.Colors
	local variant = self.Props.variant or "Primary"
	local map = {
		Primary = { c.Primary, c.TextOnPrimary, true },
		Secondary = { c.Secondary, c.TextOnPrimary, true },
		Accent = { c.Accent, c.TextOnPrimary, true },
		Success = { c.Success, c.TextOnPrimary, true },
		Danger = { c.Error, c.TextOnPrimary, true },
		Ghost = { c.Surface, c.TextPrimary, false },
	}
	local entry = map[variant] or map.Primary
	return entry[1], entry[2], entry[3]
end

function UIButtonComponent:_Style(theme: Types.UITheme)
	local c = theme.Colors
	local e = theme.Effects
	local swap = theme.Animations.ThemeSwap
	local enabled = self.Props.enabled ~= false

	local fill, textColor, filled = self:_VariantColors(theme)
	if not enabled then
		fill = c.Disabled
		textColor = c.TextSecondary
	end

	self:_Tween(self.Root, swap, { BackgroundColor3 = fill })
	self._corner.CornerRadius = UDim.new(0, theme.Radii.Medium)
	self._stroke.Color = filled and c.Stroke or c.Primary
	self._stroke.Thickness = e.StrokeThickness
	self._stroke.Transparency = filled and 0.4 or 0
	self._gradient.Enabled = e.UseGradients and filled
	self._gradient.Color = UIStyler.Gradient(90, e.GradientIntensity).Color

	self._label.FontFace = theme.Fonts.Button
	self._label.TextSize = theme.TextSizes.Button
	self._label.TextColor3 = textColor
	self._icon.TextColor3 = textColor
	self._button.Active = enabled
	self._button.AutoButtonColor = false
end

return UIButtonComponent

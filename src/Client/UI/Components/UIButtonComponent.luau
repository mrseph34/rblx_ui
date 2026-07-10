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
local ThemeShape = require(script.Parent.Parent.ThemeShape)
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
	root.BackgroundTransparency = 1
	if not props.size then
		root.Size = UDim2.new(0, 180, 0, 48)
		self._baseSize = root.Size
	end

	-- Drop shadow behind the surface (Raised3D only; hidden otherwise). A Root
	-- child so it scales/pops with the button but sits under the fill.
	local shadow = UIStyler.DropShadow(4, 1)
	shadow.Parent = root
	self._shadow = shadow

	-- Surface holds the fill + all visuals and is what hover/press scale. The
	-- Root is a fixed, transparent footprint that stays put in any layout, so
	-- the hover "pop" never reflows neighbours or spills out of a grid cell.
	local surface = UIStyler.Frame("Surface")
	surface.BackgroundTransparency = 0
	surface.Size = UDim2.fromScale(1, 1)
	surface.AnchorPoint = Vector2.new(0.5, 0.5)
	surface.Position = UDim2.fromScale(0.5, 0.5)
	surface.ClipsDescendants = true
	surface.ZIndex = 2
	surface.Parent = root
	self._surface = surface
	self:_UseScaleTarget(surface)

	self._corner = UIStyler.Corner(10)
	self._corner.Parent = surface
	self._stroke = UIStyler.Stroke(Color3.new(), 1.5)
	self._stroke.Parent = surface
	self._gradient = UIStyler.Gradient(90, 0.12)
	self._gradient.Parent = surface

	-- Inner bevel overlay for the Raised3D style (light top / dark bottom).
	-- Enabled/tuned in _Style; sits above the fill+gradient, below the content.
	local bevel = UIStyler.Bevel(1, 0)
	bevel.ZIndex = 2
	bevel.Visible = false
	bevel.Parent = surface
	self._bevel = bevel

	-- Content holds the icon + label under its own layout, separate from the
	-- Hit button so the full-size hit target never joins the content layout.
	local content = UIStyler.Frame("Content")
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.ZIndex = 3
	local layout = UIStyler.ListLayout({
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
	})
	layout.Parent = content
	content.Parent = surface

	local icon = UIStyler.TextLabel("Icon")
	icon.Size = UDim2.fromOffset(24, 24)
	icon.TextScaled = true
	icon.LayoutOrder = 1
	icon.Visible = false
	icon.Parent = content
	self._icon = icon

	local label = UIStyler.TextLabel("Label")
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.LayoutOrder = 2
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = content
	self._label = label

	-- Hit target overlays everything so the whole button is clickable.
	local button = Instance.new("TextButton")
	button.Name = "Hit"
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromScale(1, 1)
	button.Text = ""
	button.AutoButtonColor = false
	button.ZIndex = 5
	button.Parent = root
	self._button = button

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
	local enabled = self.Props.enabled ~= false

	local fill, textColor, filled = self:_VariantColors(theme)
	if not enabled then
		fill = c.Disabled
		textColor = c.TextSecondary
	end

	local shape = ThemeShape.Resolve(theme)

	self:_SetColor(self._surface, "BackgroundColor3", fill)
	-- Bubbly style rounds toward a pill; otherwise scale the Medium radius.
	local radius = shape.Style == "Bubbly"
		and math.min(self.Root.AbsoluteSize.Y / 2, theme.Radii.Pill)
		or ThemeShape.Radius(theme, theme.Radii.Medium)
	self._corner.CornerRadius = UDim.new(0, radius)
	self._stroke.Color = filled and c.Stroke or c.Primary
	self._stroke.Thickness = e.StrokeThickness
	self._stroke.Transparency = filled and 0.4 or 0
	self._gradient.Enabled = e.UseGradients and filled
	self._gradient.Color = UIStyler.Gradient(90, e.GradientIntensity).Color

	-- Raised3D: show the inner bevel + drop shadow so the button reads extruded.
	local raised = shape.Style == "Raised3D" and filled
	self._bevel.Visible = raised
	if raised then
		local beveled = UIStyler.Bevel(shape.HighlightTransparency, shape.ShadowStrength)
		local grad = beveled:FindFirstChildOfClass("UIGradient")
		local ownGrad = self._bevel:FindFirstChildOfClass("UIGradient")
		if grad and ownGrad then
			ownGrad.Transparency = grad.Transparency
		end
		beveled:Destroy()
		-- Match the bevel's own rounding to the surface so it clips cleanly.
		local bevelCorner = self._bevel:FindFirstChildOfClass("UICorner") or UIStyler.Corner(radius)
		bevelCorner.CornerRadius = UDim.new(0, radius)
		bevelCorner.Parent = self._bevel
	end
	self._shadow.ImageTransparency = raised
		and math.clamp(1 - shape.ShadowStrength * 0.9, 0, 1)
		or 1
	self._shadow.Position = UDim2.new(0.5, 0, 0.5, raised and (shape.Depth + 2) or 4)

	self._label.FontFace = theme.Fonts.Button
	self._label.TextSize = theme.TextSizes.Button
	self._label.TextColor3 = textColor
	self._icon.TextColor3 = textColor
	self._button.Active = enabled
	self._button.AutoButtonColor = false
end

return UIButtonComponent

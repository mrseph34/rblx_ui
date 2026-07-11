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
	-- Placeholder size; _Style computes the real size from the button's actual
	-- AbsoluteSize once it's resolvable (an AspectRatio constraint here would
	-- collapse to 0x0 — Size.X starts at 0 with no offset, and FitWithinMaxSize
	-- fits the ratio inside THAT zero-width box, not the button's real size).
	icon.Size = UDim2.fromOffset(24, 24)
	-- NOT TextScaled — confirmed by direct measurement that TextScaled=true on a
	-- small RichText-enabled box silently computes a degenerate size that draws
	-- nothing (TextBounds/TextSize *reported* non-zero-ish values, but nothing
	-- ever rasterized). _Style sets a concrete, computed TextSize instead, which
	-- renders reliably.
	icon.TextSize = 24
	icon.LayoutOrder = 1
	icon.Visible = false
	icon.Parent = content
	self._icon = icon

	-- Image variant of the icon (used when props.iconId is an asset id instead of
	-- an emoji). Same slot/order as the emoji icon; only one is ever visible.
	local iconImage = Instance.new("ImageLabel")
	iconImage.Name = "IconImage"
	iconImage.BackgroundTransparency = 1
	iconImage.Size = UDim2.fromOffset(24, 24)
	iconImage.LayoutOrder = 1
	iconImage.Visible = false
	iconImage.Parent = content
	self._iconImage = iconImage

	local label = UIStyler.TextLabel("Label")
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.LayoutOrder = 2
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = content
	self._label = label

	-- Hit target overlays everything so the whole button is clickable. It does
	-- NOT need to render above Surface: under the default ZIndexBehavior.Sibling,
	-- whichever ROOT-level sibling has the higher ZIndex paints its ENTIRE
	-- subtree on top of the other's — so Hit at ZIndex 5 (vs Surface's 2) was
	-- painting over Surface's whole subtree, including the icon/label inside it,
	-- no matter what ZIndex THEY had. That's what made every icon invisible.
	-- Surface is a plain Frame (Active is never set true), so it never blocks
	-- input — Hit still receives every click/tap/gamepad-A over its full bounds
	-- sitting BELOW Surface, with nothing rendered on top of the icon anymore.
	local button = Instance.new("TextButton")
	button.Name = "Hit"
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromScale(1, 1)
	button.Text = ""
	button.AutoButtonColor = false
	-- Selectable so a gamepad/console can navigate to and A-press this button;
	-- Activated (bound in _BindInteractions) fires for mouse, touch AND gamepad,
	-- so one code path serves PC, mobile and console.
	button.Selectable = true
	button.ZIndex = 1
	button.Parent = root
	self._button = button

	self:_BindInteractions(button)
	self:SetContent(props)
end

-- Update text/icon after construction without rebuilding. Supports an emoji
-- `icon`, an image `iconId`, a text label, or any combination — an icon-only
-- button, a text-only button, and an icon+text button all come from here.
function UIButtonComponent:SetContent(props: Types.UIComponentProps)
	local text = TextConfig.Resolve(props.textKey or props.text)
	self._label.Text = text
	self._label.Visible = text ~= ""
	if props.icon and props.icon ~= "" then
		-- Emoji glyph.
		self._icon.Text = props.icon
		self._icon.Visible = true
		self._iconImage.Visible = false
	elseif props.iconId and props.iconId ~= "" then
		-- Image asset.
		self._iconImage.Image = props.iconId
		self._iconImage.Visible = true
		self._icon.Visible = false
	else
		self._icon.Visible = false
		self._iconImage.Visible = false
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
	-- Ghost buttons normally get a coloured accent outline (so an unselected tab
	-- still reads as clickable) — but that stayed on even when the button was
	-- DISABLED (owned / can't-afford), leaving a bright accent-coloured ring
	-- around an otherwise greyed-out button. Disabled always gets a quiet,
	-- neutral stroke instead, regardless of variant.
	if not enabled then
		self._stroke.Color = c.Disabled
		self._stroke.Transparency = 0.5
	else
		self._stroke.Color = filled and c.Stroke or c.Primary
		self._stroke.Transparency = filled and 0.4 or 0
	end
	self._stroke.Thickness = e.StrokeThickness
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
	-- Icon scales with the button's real height instead of a fixed small size —
	-- a flat 24px icon was barely legible on a big 56-64px nav button (read as
	-- "just a colored square" with no visible icon at a glance). Clamped so it
	-- never gets comically large/tiny on unusual button sizes.
	local buttonH = self.Root.AbsoluteSize.Y
	if buttonH > 0 then
		local iconSize = math.clamp(buttonH * 0.55, 16, 40)
		self._icon.Size = UDim2.fromOffset(iconSize, iconSize)
		self._iconImage.Size = UDim2.fromOffset(iconSize, iconSize)
		-- Concrete TextSize (not TextScaled — see the _Build comment on why) so
		-- the glyph actually renders at a size proportional to the box.
		self._icon.TextSize = math.floor(iconSize * 0.85)
	end
	-- FontFace was never assigned, so the icon silently fell back to the engine
	-- default (LegacyArial) — a font with NO emoji glyph coverage at all, so
	-- every emoji icon rendered as genuinely invisible (not a screenshot quirk;
	-- confirmed on the live TextLabel: TextSize collapsed to ~8 with nothing
	-- drawn). Any modern FontFace (the theme's, same as the button label) covers
	-- emoji correctly via Roblox's normal glyph-substitution path.
	self._icon.FontFace = theme.Fonts.Button
	self._icon.TextColor3 = textColor
	self._button.Active = enabled
	self._button.Selectable = enabled -- disabled buttons drop out of gamepad nav
	self._button.AutoButtonColor = false
end

return UIButtonComponent

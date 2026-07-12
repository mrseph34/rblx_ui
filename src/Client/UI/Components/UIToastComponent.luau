--!strict
-- Transient notification toast. Slides in, holds for `duration`, slides out and
-- self-destroys. Variants tint the accent stripe/icon. Managed by the HUD
-- screen's toast stack, but self-contained enough to use anywhere.
--
-- Extra props:
--   text / textKey
--   variant  : "Info" | "Success" | "Error" | "Warning"
--   icon     : emoji override
--   duration : seconds visible (default 3)
--   onDone   : () -> ()  fired after it removes itself

local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local UIComponentBase = require(script.Parent.UIComponentBase)

local UIToastComponent = setmetatable({}, { __index = UIComponentBase })
UIToastComponent.__index = UIToastComponent

local VARIANT = {
	Info = { token = "Primary", icon = "ℹ️" },
	Success = { token = "Success", icon = "✅" },
	Error = { token = "Error", icon = "⛔" },
	Warning = { token = "Warning", icon = "⚠️" },
}

function UIToastComponent.new()
	local self = UIComponentBase.new("UIToast")
	return setmetatable(self, UIToastComponent)
end

function UIToastComponent:_Build(props: Types.UIComponentProps)
	local root = self.Root
	root.BackgroundTransparency = 0
	root.Size = UDim2.new(1, 0, 0, 44)
	self._baseSize = root.Size
	self._corner = UIStyler.Corner(10)
	self._corner.Parent = root
	self._stroke = UIStyler.Stroke(Color3.new(), 1.5)
	self._stroke.Parent = root
	UIStyler.PaddingXY(10, 0).Parent = root

	-- Stripe/Icon/Label are Scale fractions of Root (never a fixed pixel
	-- Offset), so the whole toast scales consistently with Root's own size.
	local stripe = UIStyler.Frame("Stripe")
	stripe.Size = UDim2.new(0.017, 0, 1, -12)
	stripe.Position = UDim2.new(0, 0, 0, 6)
	UIStyler.Corner(1000).Parent = stripe
	stripe.Parent = root
	self._stripe = stripe

	-- Icon box is a perfect square (AspectRatioConstraint 1:1, DominantAxis
	-- Height). Starting size is non-zero on both axes (never Scale=0) — an
	-- AspectRatioConstraint driving a Scale=0 starting dimension collapses
	-- to 0x0 instead of resolving correctly.
	local icon = UIStyler.TextLabel("Icon")
	icon.Size = UDim2.fromScale(0.6, 0.6)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0.033, 0, 0.5, 0)
	UIStyler.AspectRatio(1, Enum.DominantAxis.Height).Parent = icon
	-- NOT TextScaled — confirmed by direct measurement (see UIButtonComponent)
	-- that TextScaled on a small RichText-enabled box silently draws nothing. A
	-- concrete TextSize, computed from Root's real AbsoluteSize at Style-time
	-- (matching UIButtonComponent's icon pattern), renders reliably AND still
	-- adapts to different sizes.
	icon.TextSize = 20
	icon.Parent = root
	self._icon = icon

	local label = UIStyler.TextLabel("Label")
	label.Size = UDim2.new(0.83, 0, 1, 0)
	label.Position = UDim2.fromScale(0.15, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.TextScaled = true
	self._labelConstraint = UIStyler.TextSizeConstraint(18, 9)
	self._labelConstraint.Parent = label
	label.Parent = root
	self._label = label

	local variant = VARIANT[props.variant or "Info"] or VARIANT.Info
	self._variant = variant
	self._icon.Text = props.icon or variant.icon
	self._label.Text = TextConfig.Resolve(props.textKey or props.text)
end

-- Slide in, wait, slide out, clean up. Called by the toast stack after Create.
function UIToastComponent:Play()
	self.Root.Visible = true
	self:PlayAnimation("Appear")
	local duration = self.Props.duration or 3
	task.delay(duration, function()
		if not self.Root or not self.Root.Parent then
			return
		end
		self:PlayAnimation("Disappear")
		task.wait(self.Theme and self.Theme.Animations.Disappear.Time or 0.2)
		if self.Props.onDone then
			self.Props.onDone()
		end
		self:Destroy()
	end)
end

function UIToastComponent:_Style(theme: Types.UITheme)
	local c = theme.Colors
	local accent = (c :: any)[self._variant.token] or c.Primary
	self.Root.BackgroundColor3 = c.SurfaceRaised
	self._corner.CornerRadius = UDim.new(0, theme.Radii.Medium)
	self._stroke.Color = accent
	self._stroke.Thickness = theme.Effects.StrokeThickness
	self._stroke.Transparency = 0.2
	self._stripe.BackgroundColor3 = accent
	-- Same bug class as UIButtonComponent's icon: never assigning FontFace left
	-- this label on the engine default (LegacyArial), which has no emoji glyphs
	-- at all — the variant icon (ℹ️✅⛔⚠️) was genuinely invisible.
	self._icon.FontFace = theme.Fonts.Body
	-- Computed from the icon's real AbsoluteSize (matching UIButtonComponent's
	-- icon pattern) instead of a flat constant, so it still scales despite not
	-- being able to use TextScaled here.
	local iconH = self._icon.AbsoluteSize.Y
	if iconH > 0 then
		self._icon.TextSize = math.clamp(iconH * 0.75, 12, 32)
	end
	self._label.FontFace = theme.Fonts.Body
	self._label.TextColor3 = c.TextPrimary
	if self._labelConstraint then
		self._labelConstraint.MaxTextSize = theme.TextSizes.Body
	end
end

return UIToastComponent

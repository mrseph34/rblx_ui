--!strict
-- Prominent notification banner (level-up / achievement / unlock) — the big
-- top-center sibling of the corner toast. Slides down, holds, slides back up
-- and self-destroys. Fully themed so it matches any active style; variants tint
-- the icon badge + accent.
--
-- Props: title/titleKey, body/bodyKey, icon (emoji), variant
-- ("Info"|"Success"|"Achievement"|"LevelUp"), duration, onDone.

local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local UIComponentBase = require(script.Parent.UIComponentBase)

local UINotificationComponent = setmetatable({}, { __index = UIComponentBase })
UINotificationComponent.__index = UINotificationComponent

local VARIANT = {
	Info = { token = "Primary", icon = "ℹ️" },
	Success = { token = "Success", icon = "✅" },
	Achievement = { token = "Accent", icon = "🏆" },
	LevelUp = { token = "Secondary", icon = "⭐" },
}

function UINotificationComponent.new()
	local self = UIComponentBase.new("UINotification")
	return setmetatable(self, UINotificationComponent)
end

function UINotificationComponent:_Build(props: Types.UIComponentProps)
	local root = self.Root
	root.BackgroundTransparency = 1
	-- Fills whatever the caller's container gives it (GameHUDScreen's banner
	-- slot) instead of a fixed pixel Offset, so this popup scales with the
	-- HUD at any viewport instead of staying a constant absolute size.
	root.Size = UDim2.fromScale(1, 1)
	self._baseSize = root.Size

	local surface = UIStyler.Frame("Surface")
	surface.Size = UDim2.fromScale(1, 1)
	surface.AnchorPoint = Vector2.new(0.5, 0.5)
	surface.Position = UDim2.fromScale(0.5, 0.5)
	surface.Parent = root
	self._surface = surface
	self:_UseScaleTarget(surface)

	self._corner = UIStyler.Corner(14)
	self._corner.Parent = surface
	self._stroke = UIStyler.Stroke(Color3.new(), 1.5)
	self._stroke.Parent = surface
	self._gradient = UIStyler.Gradient(90, 0.12)
	self._gradient.Parent = surface
	UIStyler.PaddingScale(0.14).Parent = surface

	-- Icon badge (left) — a perfect circle (AspectRatioConstraint 1:1,
	-- DominantAxis Height) sized as a Scale fraction of surface instead of a
	-- fixed pixel Offset. Starting size is non-zero on both axes (never
	-- Scale=0) — an AspectRatioConstraint driving a Scale=0 starting
	-- dimension collapses to 0x0 instead of resolving correctly.
	local badge = UIStyler.Frame("Badge")
	badge.Size = UDim2.fromScale(0.5, 0.68)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, 0, 0.5, 0)
	UIStyler.AspectRatio(1, Enum.DominantAxis.Height).Parent = badge
	UIStyler.Corner(1000).Parent = badge
	badge.Parent = surface
	self._badge = badge

	local icon = UIStyler.TextLabel("Icon")
	icon.Size = UDim2.fromScale(1, 1)
	-- NOT TextScaled — confirmed by direct measurement (see UIButtonComponent)
	-- that TextScaled on a small RichText-enabled box silently draws nothing.
	-- A concrete TextSize, computed from the badge's real AbsoluteSize at
	-- Style-time (matching UIButtonComponent's icon pattern) instead of a
	-- flat constant, renders reliably AND still adapts to different sizes.
	icon.TextSize = 26
	UIStyler.PaddingScale(0.18).Parent = icon
	icon.Parent = badge
	self._icon = icon

	-- Title + body (right of badge) — Scale fractions of surface.
	local title = UIStyler.TextLabel("Title")
	title.Size = UDim2.new(0.82, 0, 0.34, 0)
	title.Position = UDim2.fromScale(0.22, 0.02)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextScaled = true
	self._titleConstraint = UIStyler.TextSizeConstraint(20, 10)
	self._titleConstraint.Parent = title
	title.Parent = surface
	self._title = title

	local body = UIStyler.TextLabel("Body")
	body.Size = UDim2.new(0.82, 0, 0.34, 0)
	body.Position = UDim2.fromScale(0.22, 0.38)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextWrapped = true
	body.TextScaled = true
	self._bodyConstraint = UIStyler.TextSizeConstraint(16, 8)
	self._bodyConstraint.Parent = body
	body.Parent = surface
	self._body = body

	local variant = VARIANT[props.variant or "Info"] or VARIANT.Info
	self._variant = variant
	self._icon.Text = props.icon or variant.icon
	self._title.Text = TextConfig.Resolve(props.titleKey or props.title)
	self._body.Text = TextConfig.Resolve(props.bodyKey or props.body)
end

-- Slide down from above, hold, slide back up, clean up.
function UINotificationComponent:Play()
	local theme = self.Theme
	local root = self.Root
	root.Visible = true
	local shown = root.Position
	root.Position = shown - UDim2.fromScale(0, 0.2)
	self:_Tween(root, theme and theme.Animations.Appear or TweenInfo.new(0.3), { Position = shown })
	self:PlayAnimation("Appear")

	local duration = self.Props.duration or 3.5
	task.delay(duration, function()
		if not root or not root.Parent then
			return
		end
		local up = shown - UDim2.fromScale(0, 0.25)
		local disappear = self.Theme and self.Theme.Animations.Disappear or TweenInfo.new(0.2)
		self:_Tween(root, disappear, { Position = up })
		task.wait(disappear.Time)
		if self.Props.onDone then
			self.Props.onDone()
		end
		self:Destroy()
	end)
end

function UINotificationComponent:_Style(theme: Types.UITheme)
	local c = theme.Colors
	local accent = (c :: any)[self._variant.token] or c.Primary
	self:_SetColor(self._surface, "BackgroundColor3", c.SurfaceRaised)
	self._corner.CornerRadius = UDim.new(0, theme.Radii.Large)
	self._stroke.Color = accent
	self._stroke.Thickness = theme.Effects.StrokeThickness
	self._stroke.Transparency = 0.15
	self._gradient.Enabled = theme.Effects.UseGradients
	self._badge.BackgroundColor3 = accent
	-- Same bug class as UIButtonComponent's icon: never assigning FontFace left
	-- this label on the engine default (LegacyArial), which has no emoji glyphs
	-- at all — the variant icon (ℹ️✅🏆⭐) was genuinely invisible.
	self._icon.FontFace = theme.Fonts.Title
	-- Computed from the badge's real AbsoluteSize (matching UIButtonComponent's
	-- icon pattern) instead of a flat constant, so it still scales with the
	-- badge at any viewport despite not being able to use TextScaled here.
	local badgeH = self._badge.AbsoluteSize.Y
	if badgeH > 0 then
		self._icon.TextSize = math.clamp(badgeH * 0.5, 14, 40)
	end
	self._title.FontFace = theme.Fonts.Title
	self._title.TextColor3 = c.TextPrimary
	if self._titleConstraint then
		self._titleConstraint.MaxTextSize = theme.TextSizes.Subtitle
	end
	self._body.FontFace = theme.Fonts.Body
	self._body.TextColor3 = c.TextSecondary
	if self._bodyConstraint then
		self._bodyConstraint.MaxTextSize = theme.TextSizes.Small
	end
end

return UINotificationComponent

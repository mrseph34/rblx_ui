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
	root.Size = UDim2.fromOffset(360, 76)
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
	UIStyler.PaddingXY(12, 10).Parent = surface

	-- Icon badge (left).
	local badge = UIStyler.Frame("Badge")
	badge.Size = UDim2.fromOffset(52, 52)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, 0, 0.5, 0)
	UIStyler.Corner(1000).Parent = badge
	badge.Parent = surface
	self._badge = badge

	local icon = UIStyler.TextLabel("Icon")
	icon.Size = UDim2.fromScale(1, 1)
	icon.TextScaled = true
	UIStyler.Padding(10).Parent = icon
	icon.Parent = badge
	self._icon = icon

	-- Title + body (right of badge).
	local title = UIStyler.TextLabel("Title")
	title.Size = UDim2.new(1, -68, 0, 26)
	title.Position = UDim2.fromOffset(64, 2)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = surface
	self._title = title

	local body = UIStyler.TextLabel("Body")
	body.Size = UDim2.new(1, -68, 0, 26)
	body.Position = UDim2.fromOffset(64, 28)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextWrapped = true
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
	self._title.FontFace = theme.Fonts.Title
	self._title.TextSize = theme.TextSizes.Subtitle
	self._title.TextColor3 = c.TextPrimary
	self._body.FontFace = theme.Fonts.Body
	self._body.TextSize = theme.TextSizes.Small
	self._body.TextColor3 = c.TextSecondary
end

return UINotificationComponent

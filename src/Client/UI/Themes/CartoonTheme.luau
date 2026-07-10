--!strict
-- Bright, rounded, bouncy. Big radii, saturated candy colors, elastic/back
-- easing and exaggerated hover pop. Mirrors the DefaultTheme token layout.

local Types = require(script.Parent.Parent.Types)

local CartoonTheme: Types.UITheme = {
	Id = "Cartoon",
	DisplayName = "Cartoon",

	Colors = {
		Primary = Color3.fromRGB(56, 182, 255),
		Secondary = Color3.fromRGB(255, 105, 180),
		Accent = Color3.fromRGB(255, 214, 51),
		Background = Color3.fromRGB(38, 198, 218),
		Surface = Color3.fromRGB(255, 255, 255),
		SurfaceRaised = Color3.fromRGB(240, 249, 255),
		Success = Color3.fromRGB(76, 217, 100),
		Warning = Color3.fromRGB(255, 179, 41),
		Error = Color3.fromRGB(255, 82, 82),
		TextPrimary = Color3.fromRGB(38, 50, 78),
		TextSecondary = Color3.fromRGB(120, 134, 168),
		TextOnPrimary = Color3.fromRGB(255, 255, 255),
		Stroke = Color3.fromRGB(38, 50, 78),
		Overlay = Color3.fromRGB(20, 30, 60),
		Disabled = Color3.fromRGB(190, 200, 214),
	},

	Fonts = {
		Title = Font.fromEnum(Enum.Font.FredokaOne),
		Subtitle = Font.fromEnum(Enum.Font.GothamBold),
		Body = Font.fromEnum(Enum.Font.GothamMedium),
		Button = Font.fromEnum(Enum.Font.FredokaOne),
		Numeric = Font.fromEnum(Enum.Font.FredokaOne),
	},

	TextSizes = {
		Title = 32,
		Subtitle = 22,
		Body = 17,
		Button = 20,
		Small = 14,
	},

	Radii = {
		Small = 12,
		Medium = 18,
		Large = 26,
		Pill = 1000,
	},

	Spacing = {
		XS = 5,
		S = 10,
		M = 14,
		L = 20,
		XL = 30,
	},

	Animations = {
		Appear = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		Disappear = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		Hover = TweenInfo.new(0.2, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		Press = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Emphasis = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		ThemeSwap = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	},

	Effects = {
		UseGradients = true,
		GradientIntensity = 0.18,
		ShadowTransparency = 0.35,
		HoverScale = 1.08,
		PressScale = 0.92,
		StrokeThickness = 3,
	},
}

return CartoonTheme

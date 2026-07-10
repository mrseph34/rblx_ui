--!strict
-- Muted, earthy, calm. Warm browns and parchment, small radii, slower Quad
-- easing and understated motion. Mirrors the DefaultTheme token layout.

local Types = require(script.Parent.Parent.Types)

local RusticTheme: Types.UITheme = {
	Id = "Rustic",
	DisplayName = "Rustic",

	Colors = {
		Primary = Color3.fromRGB(150, 105, 62),
		Secondary = Color3.fromRGB(120, 138, 92),
		Accent = Color3.fromRGB(206, 158, 74),
		Background = Color3.fromRGB(44, 38, 32),
		Surface = Color3.fromRGB(62, 53, 44),
		SurfaceRaised = Color3.fromRGB(78, 67, 55),
		Success = Color3.fromRGB(122, 156, 88),
		Warning = Color3.fromRGB(206, 158, 74),
		Error = Color3.fromRGB(176, 76, 60),
		TextPrimary = Color3.fromRGB(238, 226, 206),
		TextSecondary = Color3.fromRGB(176, 160, 138),
		TextOnPrimary = Color3.fromRGB(248, 240, 226),
		Stroke = Color3.fromRGB(98, 84, 68),
		Overlay = Color3.fromRGB(20, 16, 12),
		Disabled = Color3.fromRGB(108, 98, 86),
	},

	Fonts = {
		Title = Font.fromEnum(Enum.Font.PatrickHand),
		Subtitle = Font.fromEnum(Enum.Font.Merriweather),
		Body = Font.fromEnum(Enum.Font.Merriweather),
		Button = Font.fromEnum(Enum.Font.PatrickHand),
		Numeric = Font.fromEnum(Enum.Font.Merriweather),
	},

	TextSizes = {
		Title = 30,
		Subtitle = 21,
		Body = 16,
		Button = 19,
		Small = 13,
	},

	Radii = {
		Small = 3,
		Medium = 6,
		Large = 9,
		Pill = 1000,
	},

	Spacing = {
		XS = 4,
		S = 8,
		M = 12,
		L = 18,
		XL = 26,
	},

	Animations = {
		Appear = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Disappear = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		Hover = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Press = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Emphasis = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		ThemeSwap = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	},

	Effects = {
		UseGradients = true,
		GradientIntensity = 0.08,
		ShadowTransparency = 0.4,
		HoverScale = 1.02,
		PressScale = 0.98,
		StrokeThickness = 2,
	},
}

return RusticTheme

--!strict
-- Dark panels, neon accents, crisp fast ease-in-out. Near-black surfaces, cyan
-- and magenta glow, thin strokes. Mirrors the DefaultTheme token layout.

local Types = require(script.Parent.Parent.Types)

local SciFiTheme: Types.UITheme = {
	Id = "SciFi",
	DisplayName = "Sci-Fi",

	Colors = {
		Primary = Color3.fromRGB(0, 229, 255),
		Secondary = Color3.fromRGB(255, 45, 149),
		Accent = Color3.fromRGB(124, 255, 178),
		Background = Color3.fromRGB(8, 12, 22),
		Surface = Color3.fromRGB(16, 22, 38),
		SurfaceRaised = Color3.fromRGB(24, 34, 56),
		Success = Color3.fromRGB(56, 255, 178),
		Warning = Color3.fromRGB(255, 214, 64),
		Error = Color3.fromRGB(255, 64, 96),
		TextPrimary = Color3.fromRGB(224, 248, 255),
		TextSecondary = Color3.fromRGB(120, 156, 190),
		TextOnPrimary = Color3.fromRGB(6, 12, 22),
		Stroke = Color3.fromRGB(0, 229, 255),
		Overlay = Color3.fromRGB(0, 4, 12),
		Disabled = Color3.fromRGB(64, 78, 100),
	},

	Fonts = {
		Title = Font.fromEnum(Enum.Font.Michroma),
		Subtitle = Font.fromEnum(Enum.Font.Michroma),
		Body = Font.fromEnum(Enum.Font.Code),
		Button = Font.fromEnum(Enum.Font.Michroma),
		Numeric = Font.fromEnum(Enum.Font.Code),
	},

	TextSizes = {
		Title = 28,
		Subtitle = 19,
		Body = 15,
		Button = 17,
		Small = 12,
	},

	Radii = {
		Small = 2,
		Medium = 4,
		Large = 8,
		Pill = 1000,
	},

	Spacing = {
		XS = 4,
		S = 8,
		M = 12,
		L = 16,
		XL = 24,
	},

	Animations = {
		Appear = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		Disappear = TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
		Hover = TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		Press = TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		Emphasis = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		ThemeSwap = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut),
	},

	Effects = {
		UseGradients = true,
		GradientIntensity = 0.2,
		ShadowTransparency = 0.25,
		HoverScale = 1.03,
		PressScale = 0.97,
		StrokeThickness = 1,
	},

	-- SciFi reads as crisp, slightly extruded panels: boxier corners, subtle 3D.
	Shape = {
		RoundnessScale = 0.6,
		Style = "Raised3D",
		Depth = 3,
		HighlightTransparency = 0.85,
		ShadowStrength = 0.35,
		Bounce = 0,
	},
}

return SciFiTheme

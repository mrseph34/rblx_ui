--!strict
-- Baseline theme + the canonical token layout every other theme copies.
--
-- This exact table shape is also the target format of the in-game Theme
-- Editor's Export button: exporting a live-edited theme produces a module that
-- looks just like this one, so it can be dropped straight into this folder and
-- registered. Keep the token set here in sync with Client/UI/Types.UITheme.

local Types = require(script.Parent.Parent.Types)

local DefaultTheme: Types.UITheme = {
	Id = "Default",
	DisplayName = "Default",

	Colors = {
		Primary = Color3.fromRGB(64, 132, 255),
		Secondary = Color3.fromRGB(168, 85, 247),
		Accent = Color3.fromRGB(255, 190, 60),
		Background = Color3.fromRGB(24, 27, 35),
		Surface = Color3.fromRGB(36, 40, 52),
		SurfaceRaised = Color3.fromRGB(48, 54, 70),
		Success = Color3.fromRGB(64, 200, 120),
		Warning = Color3.fromRGB(255, 176, 32),
		Error = Color3.fromRGB(240, 76, 76),
		TextPrimary = Color3.fromRGB(240, 244, 255),
		TextSecondary = Color3.fromRGB(160, 168, 190),
		TextOnPrimary = Color3.fromRGB(255, 255, 255),
		Stroke = Color3.fromRGB(70, 78, 100),
		Overlay = Color3.fromRGB(0, 0, 0),
		Disabled = Color3.fromRGB(90, 96, 112),
	},

	Fonts = {
		Title = Font.fromEnum(Enum.Font.GothamBold),
		Subtitle = Font.fromEnum(Enum.Font.GothamMedium),
		Body = Font.fromEnum(Enum.Font.Gotham),
		Button = Font.fromEnum(Enum.Font.GothamBold),
		Numeric = Font.fromEnum(Enum.Font.GothamBold),
	},

	TextSizes = {
		Title = 28,
		Subtitle = 20,
		Body = 16,
		Button = 18,
		Small = 13,
	},

	Radii = {
		Small = 6,
		Medium = 10,
		Large = 16,
		Pill = 1000,
	},

	Spacing = {
		XS = 4,
		S = 8,
		M = 12,
		L = 18,
		XL = 28,
	},

	Animations = {
		Appear = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		Disappear = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		Hover = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Press = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Emphasis = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		ThemeSwap = TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	},

	Effects = {
		UseGradients = true,
		GradientIntensity = 0.12,
		ShadowTransparency = 0.55,
		HoverScale = 1.04,
		PressScale = 0.96,
		StrokeThickness = 1.5,
	},
}

return DefaultTheme

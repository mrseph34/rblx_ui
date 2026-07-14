--!strict
-- THE Default base theme (skin) for this UI system — the boxy "bloxy" Roblox look
-- we built. Its colour tokens are the EXACT reference palette (RefSkin.C) so every
-- themed component matches the reference bar-for-bar. (The shop row itself renders
-- straight through RefSkin for pixel parity; these tokens carry that same palette
-- to buttons / panels / toggles / etc.) The boxy nested-box STRUCTURE lives in the
-- components; this theme is purely the COLOUR/font/shape token set. This is the
-- default theme (see UIThemeConfig.DefaultThemeId).
--
-- Token→element notes (why these particular colours were chosen — see the
-- component _Style methods that consume them):
--   * SurfaceRaised paints BOTH the panel title bar (UIPanelComponent) AND the
--     shop card/row inner (UICardComponent/UIListRowComponent), so it's a light
--     SKY blue: saturated enough to read as the reference's blue header/tiles,
--     light enough that the white outlined text on it stays legible.
--   * Surface (panel body / Ghost button fill / row "gap" frame) is a paler blue
--     so the SurfaceRaised inner sits a shade "up" from it (the nested-box depth).
--   * Primary (azure) carries the brand on buttons, Ghost outlines, the nav rail
--     and the shop row image box; Secondary (purple) is the alt currency; Accent
--     (gold) is the shop row label line; Success (green) is buy/sell; Error (red)
--     is the ✖ close.

local Types = require(script.Parent.Parent.Types)

local DefaultTheme: Types.UITheme = {
	Id = "Default",
	DisplayName = "Default",

	Colors = {
		-- The EXACT reference palette (RefSkin.C) so themed components match the
		-- reference we built. (RGB comments name the reference swatch each maps to.)
		Primary = Color3.fromRGB(64, 132, 236),        -- C.Blue
		Secondary = Color3.fromRGB(168, 84, 234),      -- C.PurpleTop
		Accent = Color3.fromRGB(255, 197, 66),         -- C.Gold
		Background = Color3.fromRGB(20, 44, 92),        -- ~C.Outline navy
		Surface = Color3.fromRGB(224, 238, 251),       -- C.CardTop
		SurfaceRaised = Color3.fromRGB(96, 178, 246),   -- C.TitleTop (reference blue header)
		Success = Color3.fromRGB(110, 200, 80),         -- ~C.GreenTop/GreenBottom
		Warning = Color3.fromRGB(255, 176, 52),
		Error = Color3.fromRGB(228, 62, 62),           -- C.Red
		-- All text is WHITE for this boxy base UI — the dark TextOutline keeps it
		-- legible on any surface (the chunky-Roblox look).
		TextPrimary = Color3.fromRGB(255, 255, 255),
		TextSecondary = Color3.fromRGB(238, 244, 252),
		TextOnPrimary = Color3.fromRGB(255, 255, 255),
		Stroke = Color3.fromRGB(19, 42, 92),           -- C.Outline
		Overlay = Color3.fromRGB(8, 22, 52),
		Disabled = Color3.fromRGB(150, 158, 168),      -- ~C.GrayBottom
	},

	Fonts = {
		Title = Font.fromEnum(Enum.Font.FredokaOne),
		Subtitle = Font.fromEnum(Enum.Font.GothamBold),
		Body = Font.fromEnum(Enum.Font.GothamMedium),
		Button = Font.fromEnum(Enum.Font.FredokaOne),
		Numeric = Font.fromEnum(Enum.Font.FredokaOne),
	},

	TextSizes = {
		Title = 30,
		Subtitle = 22,
		Body = 17,
		Button = 20,
		Small = 14,
	},

	-- Square corners (the reference look); Pill stays round for bars/chips.
	Radii = {
		Small = 0,
		Medium = 0,
		Large = 0,
		Pill = 1000,
	},

	Spacing = {
		XS = 5,
		S = 9,
		M = 13,
		L = 19,
		XL = 28,
	},

	Animations = {
		Appear = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		Disappear = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		Hover = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Press = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Emphasis = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		ThemeSwap = TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	},

	Effects = {
		UseGradients = true,
		GradientIntensity = 0.14,
		ShadowTransparency = 0.5,
		HoverScale = 1.05,
		PressScale = 0.95,
		StrokeThickness = 3,
	},

	-- Flat fills + a bold navy outline + a subtle top-light gradient — the
	-- reference's look — with corners a touch rounder than baseline (chunky, but
	-- not the full pills a Bubbly style would force on the buttons).
	Shape = {
		RoundnessScale = 1,
		Style = "Flat",
		Depth = 0,
		HighlightTransparency = 1,
		ShadowStrength = 0,
		Bounce = 0,
	},

	-- No studs texture at the theme level — studs are intentionally scoped to just
	-- the Store's pack panel + option cards (see RefExclusiveStore), so the rest of
	-- the UI stays clean. Omitting Texture makes every component's ConfigureTexture
	-- hide its stud layer.

	-- The reference's defining feature: a bold navy outline around text (and
	-- slider/toggle knob borders). Also what makes gold prices / white button
	-- labels pop on the light fills. Thickness is the one knob to tune if the
	-- outline reads too heavy on small body text.
	TextOutline = {
		Color = Color3.fromRGB(19, 42, 92), -- C.Outline (reference navy)
		Thickness = 2,
		Transparency = 0,
	},
}

return DefaultTheme

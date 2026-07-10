--!strict
-- A batch of extra "style" themes generated from one canonical base + compact
-- per-style overrides. Each entry is still a full, standalone Types.UITheme (so
-- the editor, serializer and controller treat them exactly like the hand-written
-- themes) — this file just avoids repeating 80 identical lines twelve times.
--
-- The emphasis here is on *shape/feel* variety (Flat / Bubbly / Raised3D,
-- roundness, depth) to pair with the existing colour-led themes. Add a style by
-- appending one row to STYLES; it inherits every unspecified token from BASE.

local Types = require(script.Parent.Parent.Types)
local DefaultTheme = require(script.Parent.DefaultTheme)

local StyleThemes = {}

-- Deep-ish clone of the Default theme's sub-tables so an override never mutates
-- the shared DefaultTheme instance.
local function cloneBase(): Types.UITheme
	local d = DefaultTheme
	return {
		Id = d.Id,
		DisplayName = d.DisplayName,
		Colors = table.clone(d.Colors),
		Fonts = table.clone(d.Fonts),
		TextSizes = table.clone(d.TextSizes),
		Radii = table.clone(d.Radii),
		Spacing = table.clone(d.Spacing),
		Animations = table.clone(d.Animations),
		Effects = table.clone(d.Effects),
		Shape = d.Shape and table.clone(d.Shape) or nil,
	}
end

local gothamBold = Font.fromEnum(Enum.Font.GothamBold)
local gotham = Font.fromEnum(Enum.Font.Gotham)

-- Each style: id/name, a palette, a font pick, and a shape. Everything else is
-- inherited from Default. Keeping these declarative makes the variety obvious.
local STYLES = {
	-- ---- Flat / clean ------------------------------------------------------
	{
		Id = "Midnight", Name = "Midnight (Flat)",
		Colors = { Primary = Color3.fromRGB(99, 102, 241), Secondary = Color3.fromRGB(139, 92, 246), Accent = Color3.fromRGB(56, 189, 248), Background = Color3.fromRGB(15, 17, 26), Surface = Color3.fromRGB(24, 27, 40), SurfaceRaised = Color3.fromRGB(33, 37, 54) },
		Shape = { RoundnessScale = 1, Style = "Flat", Depth = 0, HighlightTransparency = 1, ShadowStrength = 0, Bounce = 0 },
	},
	{
		Id = "Paper", Name = "Paper (Light Flat)",
		Colors = { Primary = Color3.fromRGB(37, 99, 235), Secondary = Color3.fromRGB(219, 39, 119), Accent = Color3.fromRGB(234, 88, 12), Background = Color3.fromRGB(244, 245, 248), Surface = Color3.fromRGB(255, 255, 255), SurfaceRaised = Color3.fromRGB(236, 238, 243), TextPrimary = Color3.fromRGB(24, 27, 35), TextSecondary = Color3.fromRGB(90, 98, 116), Stroke = Color3.fromRGB(210, 214, 224) },
		Shape = { RoundnessScale = 0.9, Style = "Flat", Depth = 0, HighlightTransparency = 1, ShadowStrength = 0, Bounce = 0 },
	},
	{
		Id = "Mono", Name = "Mono (Boxy Flat)",
		Colors = { Primary = Color3.fromRGB(229, 231, 235), Secondary = Color3.fromRGB(156, 163, 175), Accent = Color3.fromRGB(250, 204, 21), Background = Color3.fromRGB(10, 10, 12), Surface = Color3.fromRGB(22, 22, 26), SurfaceRaised = Color3.fromRGB(32, 32, 38), TextOnPrimary = Color3.fromRGB(10, 10, 12) },
		Shape = { RoundnessScale = 0.25, Style = "Flat", Depth = 0, HighlightTransparency = 1, ShadowStrength = 0, Bounce = 0 },
	},

	-- ---- Bubbly / round ----------------------------------------------------
	{
		Id = "Bubblegum", Name = "Bubblegum (Bubbly)",
		Colors = { Primary = Color3.fromRGB(244, 114, 182), Secondary = Color3.fromRGB(129, 140, 248), Accent = Color3.fromRGB(52, 211, 153), Background = Color3.fromRGB(40, 24, 46), Surface = Color3.fromRGB(58, 36, 66), SurfaceRaised = Color3.fromRGB(76, 48, 86) },
		Shape = { RoundnessScale = 2, Style = "Bubbly", Depth = 0, HighlightTransparency = 1, ShadowStrength = 0, Bounce = 0.06 },
	},
	{
		Id = "Candy", Name = "Candy (Bubbly Light)",
		Colors = { Primary = Color3.fromRGB(251, 113, 133), Secondary = Color3.fromRGB(96, 165, 250), Accent = Color3.fromRGB(163, 230, 53), Background = Color3.fromRGB(255, 247, 250), Surface = Color3.fromRGB(255, 255, 255), SurfaceRaised = Color3.fromRGB(255, 236, 242), TextPrimary = Color3.fromRGB(60, 30, 45), TextSecondary = Color3.fromRGB(150, 110, 125), Stroke = Color3.fromRGB(248, 210, 222) },
		Shape = { RoundnessScale = 2.2, Style = "Bubbly", Depth = 0, HighlightTransparency = 1, ShadowStrength = 0, Bounce = 0.07 },
	},
	{
		Id = "Jelly", Name = "Jelly (Springy)",
		Colors = { Primary = Color3.fromRGB(45, 212, 191), Secondary = Color3.fromRGB(250, 204, 21), Accent = Color3.fromRGB(232, 121, 249), Background = Color3.fromRGB(12, 34, 38), Surface = Color3.fromRGB(18, 48, 52), SurfaceRaised = Color3.fromRGB(26, 64, 68) },
		Shape = { RoundnessScale = 1.9, Style = "Bubbly", Depth = 0, HighlightTransparency = 1, ShadowStrength = 0, Bounce = 0.08 },
	},

	-- ---- Raised3D / AAA extruded ------------------------------------------
	{
		Id = "Emboss", Name = "Emboss (3D AAA)",
		Colors = { Primary = Color3.fromRGB(59, 130, 246), Secondary = Color3.fromRGB(168, 85, 247), Accent = Color3.fromRGB(251, 191, 36), Background = Color3.fromRGB(20, 24, 33), Surface = Color3.fromRGB(30, 36, 49), SurfaceRaised = Color3.fromRGB(42, 50, 68) },
		Shape = { RoundnessScale = 1, Style = "Raised3D", Depth = 4, HighlightTransparency = 0.7, ShadowStrength = 0.55, Bounce = 0 },
	},
	{
		Id = "Plastic", Name = "Plastic (3D Glossy)",
		Colors = { Primary = Color3.fromRGB(239, 68, 68), Secondary = Color3.fromRGB(59, 130, 246), Accent = Color3.fromRGB(250, 204, 21), Background = Color3.fromRGB(28, 30, 38), Surface = Color3.fromRGB(40, 43, 54), SurfaceRaised = Color3.fromRGB(54, 58, 72) },
		Shape = { RoundnessScale = 1.5, Style = "Raised3D", Depth = 5, HighlightTransparency = 0.55, ShadowStrength = 0.6, Bounce = 0.02 },
		Gradient = 0.22,
	},
	{
		Id = "Metal", Name = "Metal (3D Brushed)",
		Colors = { Primary = Color3.fromRGB(148, 163, 184), Secondary = Color3.fromRGB(100, 116, 139), Accent = Color3.fromRGB(56, 189, 248), Background = Color3.fromRGB(17, 20, 26), Surface = Color3.fromRGB(30, 34, 43), SurfaceRaised = Color3.fromRGB(44, 50, 62), TextOnPrimary = Color3.fromRGB(17, 20, 26) },
		Shape = { RoundnessScale = 0.5, Style = "Raised3D", Depth = 3, HighlightTransparency = 0.6, ShadowStrength = 0.5, Bounce = 0 },
		Gradient = 0.28,
	},
	{
		Id = "Gemstone", Name = "Gemstone (3D Round)",
		Colors = { Primary = Color3.fromRGB(139, 92, 246), Secondary = Color3.fromRGB(236, 72, 153), Accent = Color3.fromRGB(45, 212, 191), Background = Color3.fromRGB(23, 18, 38), Surface = Color3.fromRGB(34, 27, 54), SurfaceRaised = Color3.fromRGB(48, 38, 74) },
		Shape = { RoundnessScale = 1.8, Style = "Raised3D", Depth = 4, HighlightTransparency = 0.5, ShadowStrength = 0.55, Bounce = 0.03 },
		Gradient = 0.2,
	},

	-- ---- Themed accent variants -------------------------------------------
	{
		Id = "Toxic", Name = "Toxic (Neon 3D)",
		Colors = { Primary = Color3.fromRGB(132, 204, 22), Secondary = Color3.fromRGB(34, 197, 94), Accent = Color3.fromRGB(190, 242, 100), Background = Color3.fromRGB(12, 20, 8), Surface = Color3.fromRGB(20, 32, 14), SurfaceRaised = Color3.fromRGB(30, 46, 20), TextOnPrimary = Color3.fromRGB(12, 20, 8) },
		Shape = { RoundnessScale = 0.8, Style = "Raised3D", Depth = 3, HighlightTransparency = 0.6, ShadowStrength = 0.5, Bounce = 0 },
	},
	{
		Id = "Sunset", Name = "Sunset (Warm Bubbly)",
		Colors = { Primary = Color3.fromRGB(249, 115, 22), Secondary = Color3.fromRGB(239, 68, 68), Accent = Color3.fromRGB(250, 204, 21), Background = Color3.fromRGB(38, 20, 24), Surface = Color3.fromRGB(54, 30, 34), SurfaceRaised = Color3.fromRGB(72, 42, 46) },
		Shape = { RoundnessScale = 1.7, Style = "Bubbly", Depth = 0, HighlightTransparency = 1, ShadowStrength = 0, Bounce = 0.05 },
	},
}

local built: { Types.UITheme } = {}

for _, style in STYLES do
	local theme = cloneBase()
	theme.Id = style.Id
	theme.DisplayName = style.Name

	for token, value in style.Colors do
		(theme.Colors :: any)[token] = value
	end

	if style.Font then
		theme.Fonts = table.clone(theme.Fonts)
		theme.Fonts.Title = style.Font
		theme.Fonts.Button = style.Font
	else
		-- Keep GothamBold titles/buttons, Gotham body (the Default pairing).
		theme.Fonts.Title = gothamBold
		theme.Fonts.Body = gotham
	end

	theme.Shape = style.Shape

	if style.Gradient then
		theme.Effects = table.clone(theme.Effects)
		theme.Effects.UseGradients = true
		theme.Effects.GradientIntensity = style.Gradient
	end

	table.insert(built, theme)
end

StyleThemes.Themes = built

return StyleThemes

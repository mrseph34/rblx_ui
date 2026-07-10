--!strict
-- Resolves a theme's optional Shape token into a guaranteed-complete shape, and
-- exposes shape-derived helpers every component uses so the "feel" (roundness,
-- Flat/Bubbly/Raised3D) is decided in exactly one place.
--
-- Why a helper instead of a required field: existing hand-written themes predate
-- Shape. Making it required would force editing every theme at once and risk the
-- consistency guarantee. Instead Shape is optional on the theme and Resolve()
-- fills a Flat default, so every component can call ThemeShape.* unconditionally.

local Types = require(script.Parent.Types)

local ThemeShape = {}

-- The Flat baseline used when a theme omits Shape (behaves exactly like before).
local DEFAULT: Types.UIThemeShape = {
	RoundnessScale = 1,
	Style = "Flat",
	Depth = 0,
	HighlightTransparency = 1,
	ShadowStrength = 0,
	Bounce = 0,
}

function ThemeShape.Resolve(theme: Types.UITheme): Types.UIThemeShape
	local s = theme.Shape
	if not s then
		return DEFAULT
	end
	-- Layer onto DEFAULT so a partially-specified Shape is still complete.
	return {
		RoundnessScale = s.RoundnessScale or DEFAULT.RoundnessScale,
		Style = s.Style or DEFAULT.Style,
		Depth = s.Depth or DEFAULT.Depth,
		HighlightTransparency = s.HighlightTransparency ~= nil and s.HighlightTransparency or DEFAULT.HighlightTransparency,
		ShadowStrength = s.ShadowStrength or DEFAULT.ShadowStrength,
		Bounce = s.Bounce or DEFAULT.Bounce,
	}
end

-- Apply the theme's roundness scale to a base radius (in px). Clamped so a very
-- round style still can't exceed a full pill on small elements.
function ThemeShape.Radius(theme: Types.UITheme, baseRadius: number): number
	local shape = ThemeShape.Resolve(theme)
	return math.floor(baseRadius * shape.RoundnessScale + 0.5)
end

function ThemeShape.IsRaised(theme: Types.UITheme): boolean
	return ThemeShape.Resolve(theme).Style == "Raised3D"
end

function ThemeShape.IsBubbly(theme: Types.UITheme): boolean
	return ThemeShape.Resolve(theme).Style == "Bubbly"
end

-- Hover scale a component should use, blending the theme's Effects.HoverScale
-- with any extra Bubbly bounce so springy styles feel springier without each
-- component special-casing the style.
function ThemeShape.HoverScale(theme: Types.UITheme): number
	local shape = ThemeShape.Resolve(theme)
	return theme.Effects.HoverScale + shape.Bounce
end

return ThemeShape

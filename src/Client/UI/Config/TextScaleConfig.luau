--!strict
-- One tunable knob for every "text sitting inside a smaller sub-box inside a
-- component" case (button labels, badges, category tabs, buy-button text) —
-- TextScaled = true on a Size = {SubBoxFrac, 0}, {SubBoxFrac, 0} box centred
-- inside the component's own root, instead of each component computing its
-- own AbsoluteSize-derived TextSize independently. Editable live from the
-- Theme Editor (see ThemeSelectorScreen) so the whole UI's secondary text
-- density can be tuned without touching code.
--
-- Does NOT apply to panel titles (UIPanelComponent.Title) or shop card names/
-- prices (UICardComponent), which have their own dedicated TextSizeConstraint
-- tuning — this is specifically the shared "small text in a themed chip/
-- button" pattern.

local TextScaleConfig = {}

-- The sub-box's size as a fraction of its parent (both axes) — text inside it
-- is TextScaled, so it fills exactly this fraction of the component's own
-- resolved size, then shrinks further to fit the actual glyph string.
TextScaleConfig.SubBoxFraction = 0.65

-- Multiplies every TextScaled element's MaxTextSize cap (button labels, badge
-- labels, panel titles) — the one live-editable knob for "how large can
-- secondary/chip text get before TextScaled stops growing it," exposed as a
-- slider in the Theme Editor (see ThemeSelectorScreen). 1 = unchanged theme
-- caps; <1 shrinks every cap, >1 raises them.
TextScaleConfig.MaxSizeMultiplier = 1

function TextScaleConfig.SubBoxSize(): UDim2
	local f = TextScaleConfig.SubBoxFraction
	return UDim2.fromScale(f, f)
end

-- Applies MaxSizeMultiplier to a base (theme) cap, floored at 1px.
function TextScaleConfig.ScaledCap(baseCap: number): number
	return math.max(1, math.floor(baseCap * TextScaleConfig.MaxSizeMultiplier))
end

return TextScaleConfig

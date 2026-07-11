--!strict
-- Named PANEL ANIMATION packs — how every panel/modal/menu ANIMATES IN when it
-- opens. Each pack is a single transform the panel starts from and tweens to its
-- resting spot; the panel plays the SAME transform in REVERSE to animate OUT on
-- close (so a menu that slid in from the left slides back out to the left, a
-- menu that grew in shrinks back down — nothing ever just pops out of existence).
--
-- Orthogonal to themes/packs/layout. Switch the active pack with
-- PanelAnimConfig.SetActive(id) (or the Theme Editor's Animations picker / the
-- Studio UIDebug SetAnimPack seam). Add a pack by appending here.

local PanelAnimConfig = {}

-- mode:
--   "Scale" -> starts scaled by `scale` (via UIScale), tweens to 1. Grow/pop.
--   "Slide" -> starts offset by `offset` (a UDim2 delta added to the resting
--              Position), tweens to the resting Position. Slide from any side.
-- Every pack keeps the panel fully opaque the whole time (no transparency tween,
-- which would fight the themed shadow/stroke values) — motion alone reads clean.
export type AnimPack = {
	id: string,
	displayName: string,
	icon: string,
	mode: "Scale" | "Slide",
	scale: number?, -- Scale mode: starting scale (e.g. 0.85)
	offset: UDim2?, -- Slide mode: starting offset from the resting position
}

PanelAnimConfig.Packs = {
	{ id = "grow", displayName = "Grow", icon = "🔎", mode = "Scale", scale = 0.85 },
	{ id = "pop", displayName = "Pop", icon = "✨", mode = "Scale", scale = 0.6 },
	{ id = "slideLeft", displayName = "Slide from Left", icon = "⬅️", mode = "Slide", offset = UDim2.fromScale(-0.6, 0) },
	{ id = "slideRight", displayName = "Slide from Right", icon = "➡️", mode = "Slide", offset = UDim2.fromScale(0.6, 0) },
	{ id = "slideUp", displayName = "Slide from Bottom", icon = "⬆️", mode = "Slide", offset = UDim2.fromScale(0, 0.6) },
	{ id = "slideDown", displayName = "Slide from Top", icon = "⬇️", mode = "Slide", offset = UDim2.fromScale(0, -0.6) },
} :: { AnimPack }

PanelAnimConfig.DefaultId = "grow"
-- Mutable active-pack id; the panel reads this each time it animates.
PanelAnimConfig.ActiveId = PanelAnimConfig.DefaultId

function PanelAnimConfig.Get(id: string): AnimPack?
	for _, pack in PanelAnimConfig.Packs do
		if pack.id == id then
			return pack
		end
	end
	return nil
end

function PanelAnimConfig.Active(): AnimPack
	return PanelAnimConfig.Get(PanelAnimConfig.ActiveId) or PanelAnimConfig.Packs[1]
end

function PanelAnimConfig.SetActive(id: string): boolean
	if PanelAnimConfig.Get(id) then
		PanelAnimConfig.ActiveId = id
		return true
	end
	return false
end

return PanelAnimConfig

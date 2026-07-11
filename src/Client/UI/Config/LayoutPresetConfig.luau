--!strict
-- Named, ready-to-apply on-screen LAYOUT presets — bundles of "where does each
-- piece of UI live" that the game (or a dev, at runtime) can switch between
-- without editing any screen code. A preset relocates the floating nav rail
-- (which side/corner it hugs, vertical column vs horizontal toolbar, labelled
-- or icon-only) and the HUD (which region the money chips, vitals bars, and
-- other stats sit in, plus an optional HUD scale).
--
-- This is deliberately orthogonal to both THEMES (look) and PACKS (how the shop
-- data is arranged). A preset only moves things around the screen, so any
-- preset combines with any theme and any pack.
--
-- Apply one with UILayoutController:Apply(id) (a nav rebuild + HUD relayout), or
-- from the Theme Editor's Layout picker / the Studio UIDebug seam. Add a preset
-- by appending here — no handler or screen edits.

local LayoutPresetConfig = {}

-- HUD regions an element can be sent to (must match GameHUDScreen.REGION_LAYOUT):
--   "TopLeft" | "TopCenter" | "TopRight" | "BottomLeft" | "BottomCenter" | "BottomRight"
export type NavLayout = {
	side: "Left" | "Right",
	vertical: "Top" | "Center" | "Bottom",
	fill: "Vertical" | "Horizontal",
	showLabels: boolean,
}
export type HUDLayout = {
	-- Region for the currency chips (coins + gems).
	money: string,
	-- Optional per-element region overrides (e.g. put the vitals bars center).
	regions: { [string]: string }?,
	-- Optional HUD UIScale override; nil = keep the active pack's scale.
	scale: number?,
}
export type LayoutPreset = {
	id: string,
	displayName: string,
	icon: string,
	description: string,
	nav: NavLayout,
	hud: HUDLayout,
}

local VITALS_CENTER = { health = "BottomCenter", mana = "BottomCenter", stamina = "BottomCenter" }
local VITALS_RIGHT = { health = "BottomRight", mana = "BottomRight", stamina = "BottomRight" }

LayoutPresetConfig.DefaultPresetId = "classic"

LayoutPresetConfig.Presets = {
	{
		id = "classic", displayName = "Classic", icon = "🎮",
		description = "Left rail, money top-right, vitals bottom-left.",
		nav = { side = "Left", vertical = "Center", fill = "Vertical", showLabels = true },
		hud = { money = "TopRight" },
	},
	{
		id = "console", displayName = "Console", icon = "🕹️",
		description = "Icon-only bottom toolbar for controller play.",
		nav = { side = "Left", vertical = "Bottom", fill = "Horizontal", showLabels = false },
		hud = { money = "TopRight" },
	},
	{
		id = "mobileThumbs", displayName = "Mobile Thumbs", icon = "📱",
		description = "Right-bottom icon rail, vitals centered — thumb-reachable.",
		nav = { side = "Right", vertical = "Bottom", fill = "Vertical", showLabels = false },
		hud = { money = "TopLeft", regions = VITALS_CENTER },
	},
	{
		id = "minimalLeft", displayName = "Minimal", icon = "▫️",
		description = "Small icon rail top-left, nothing else moved.",
		nav = { side = "Left", vertical = "Top", fill = "Vertical", showLabels = false },
		hud = { money = "TopRight", scale = 0.9 },
	},
	{
		id = "rightRail", displayName = "Right Rail", icon = "➡️",
		description = "Labelled rail on the right, money top-left.",
		nav = { side = "Right", vertical = "Center", fill = "Vertical", showLabels = true },
		hud = { money = "TopLeft" },
	},
	{
		id = "topToolbar", displayName = "Top Toolbar", icon = "🔝",
		description = "Horizontal labelled toolbar across the top-left.",
		nav = { side = "Left", vertical = "Top", fill = "Horizontal", showLabels = true },
		hud = { money = "TopRight" },
	},
	{
		id = "streamer", displayName = "Streamer", icon = "🎥",
		description = "Money + vitals centered, rail left — clean for capture.",
		nav = { side = "Left", vertical = "Center", fill = "Vertical", showLabels = true },
		hud = { money = "TopCenter", regions = VITALS_CENTER },
	},
	{
		id = "cinematic", displayName = "Cinematic", icon = "🎬",
		description = "Slim right icon rail, scaled-down HUD.",
		nav = { side = "Right", vertical = "Bottom", fill = "Vertical", showLabels = false },
		hud = { money = "TopLeft", scale = 0.85 },
	},
	{
		id = "bossFight", displayName = "Boss Fight", icon = "⚔️",
		description = "Vitals bar bottom-center, rail out of the way on the right.",
		nav = { side = "Right", vertical = "Center", fill = "Vertical", showLabels = false },
		hud = { money = "TopRight", regions = VITALS_CENTER },
	},
	{
		id = "southpaw", displayName = "Southpaw", icon = "🫲",
		description = "Everything mirrored to the right for left-handed play.",
		nav = { side = "Right", vertical = "Bottom", fill = "Vertical", showLabels = true },
		hud = { money = "TopRight", regions = VITALS_RIGHT },
	},
	{
		id = "dashboard", displayName = "Dashboard", icon = "📊",
		description = "Money centered up top, labelled left rail.",
		nav = { side = "Left", vertical = "Center", fill = "Vertical", showLabels = true },
		hud = { money = "TopCenter" },
	},
	{
		id = "compact", displayName = "Compact", icon = "🗜️",
		description = "Tiny top toolbar, shrunken HUD — max play space.",
		nav = { side = "Left", vertical = "Top", fill = "Horizontal", showLabels = false },
		hud = { money = "TopRight", scale = 0.8 },
	},
} :: { LayoutPreset }

function LayoutPresetConfig.Get(id: string): LayoutPreset?
	for _, preset in LayoutPresetConfig.Presets do
		if preset.id == id then
			return preset
		end
	end
	return nil
end

return LayoutPresetConfig

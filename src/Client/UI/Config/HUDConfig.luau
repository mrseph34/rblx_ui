--!strict
-- Declarative description of the HUD. Each element names a value key (filled at
-- runtime by GameHUDScreen:Update), a display format, and a screen region.
-- Rearranging or adding a HUD stat is a data edit here — GameHUDScreen renders
-- whatever this list contains.

local Types = require(script.Parent.Parent.Types)

local HUDConfig = {}

-- Regions map to anchored containers the HUD screen creates.
-- "TopLeft" | "TopCenter" | "TopRight" | "BottomLeft" | "BottomCenter"
HUDConfig.Elements = {
	{ id = "coins", format = "Number", region = "TopRight", order = 1, labelKey = "currency.coins", icon = "💰", colorToken = "Accent" },
	{ id = "gems", format = "Number", region = "TopRight", order = 2, labelKey = "currency.gems", icon = "💎", colorToken = "Secondary" },
	{ id = "wave", format = "Number", region = "TopCenter", order = 1, labelKey = "hud.wave", icon = "🌊", colorToken = "Primary" },
	{ id = "timer", format = "Time", region = "TopCenter", order = 2, labelKey = "hud.timer", icon = "⏱️", colorToken = "TextPrimary" },
	{ id = "level", format = "Number", region = "TopLeft", order = 1, labelKey = "hud.level", icon = "⭐", colorToken = "Accent" },
	-- Vitals: the classic health / mana / stamina stack. Grouped bottom-left so
	-- they read as one block; move any of them with SetElementRegion or a pack's
	-- HUD.Regions (e.g. put health BottomCenter for a boss-fight feel).
	{ id = "health", format = "Bar", region = "BottomLeft", order = 1, labelKey = "hud.health", icon = "❤️", maxValue = 100, colorToken = "Error" },
	{ id = "mana", format = "Bar", region = "BottomLeft", order = 2, labelKey = "hud.mana", icon = "🔷", maxValue = 100, colorToken = "Primary" },
	{ id = "stamina", format = "Bar", region = "BottomLeft", order = 3, labelKey = "hud.stamina", icon = "⚡", maxValue = 100, colorToken = "Success" },
} :: { Types.HUDElement }

HUDConfig.DefaultValues = {
	coins = 750,
	gems = 120,
	wave = 1,
	timer = 90,
	level = 7,
	health = 100,
	mana = 72,
	stamina = 88,
}

function HUDConfig.GetElementsForRegion(region: string): { Types.HUDElement }
	local out = {}
	for _, element in HUDConfig.Elements do
		if element.region == region then
			table.insert(out, element)
		end
	end
	table.sort(out, function(a, b)
		return a.order < b.order
	end)
	return out
end

-- Seconds -> "M:SS" for Time-format elements.
function HUDConfig.FormatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return HUDConfig

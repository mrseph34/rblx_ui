--!strict
-- Data-driven settings menu. Sections group rows; each row is a toggle, a slider
-- or a dropdown, referenced by id and rendered by SettingsScreen with the shared
-- toggle/slider/dropdown components — so every row is structurally consistent and
-- adding a setting is a data edit here, never a UI edit.
--
-- This is the "text-heavy menu" pack the shop layout can't cover: labelled option
-- rows in titled sections, the classic pause-menu / options screen.

local SettingsConfig = {}

export type SettingsRow = {
	id: string,
	kind: "Toggle" | "Slider" | "Dropdown",
	labelKey: string,
	-- Toggle:
	default: any,
	-- Slider:
	min: number?,
	max: number?,
	step: number?,
	decimals: number?,
	-- Dropdown:
	options: { { id: string, textKey: string } }?,
}

export type SettingsSection = {
	id: string,
	titleKey: string,
	rows: { SettingsRow },
}

SettingsConfig.Sections = {
	{
		id = "audio",
		titleKey = "settings.section.audio",
		rows = {
			{ id = "master_volume", kind = "Slider", labelKey = "settings.master_volume", default = 80, min = 0, max = 100, step = 1, decimals = 0 },
			{ id = "music_volume", kind = "Slider", labelKey = "settings.music_volume", default = 60, min = 0, max = 100, step = 1, decimals = 0 },
			{ id = "sfx_enabled", kind = "Toggle", labelKey = "settings.sfx_enabled", default = true },
		},
	},
	{
		id = "display",
		titleKey = "settings.section.display",
		rows = {
			{ id = "ui_scale", kind = "Slider", labelKey = "settings.ui_scale", default = 1, min = 0.7, max = 1.4, step = 0.05, decimals = 2 },
			{ id = "reduced_motion", kind = "Toggle", labelKey = "settings.reduced_motion", default = false },
			{
				id = "quality",
				kind = "Dropdown",
				labelKey = "settings.quality",
				default = "high",
				options = {
					{ id = "low", textKey = "settings.quality.low" },
					{ id = "medium", textKey = "settings.quality.medium" },
					{ id = "high", textKey = "settings.quality.high" },
				},
			},
		},
	},
	{
		id = "gameplay",
		titleKey = "settings.section.gameplay",
		rows = {
			{ id = "show_damage", kind = "Toggle", labelKey = "settings.show_damage", default = true },
			{ id = "show_overheads", kind = "Toggle", labelKey = "settings.show_overheads", default = true },
			{
				id = "camera_side",
				kind = "Dropdown",
				labelKey = "settings.camera_side",
				default = "right",
				options = {
					{ id = "left", textKey = "settings.side.left" },
					{ id = "right", textKey = "settings.side.right" },
				},
			},
		},
	},
} :: { SettingsSection }

-- Flat map of every row's default value, used to seed the live settings state.
function SettingsConfig.Defaults(): { [string]: any }
	local out = {}
	for _, section in SettingsConfig.Sections do
		for _, row in section.rows do
			out[row.id] = row.default
		end
	end
	return out
end

return SettingsConfig

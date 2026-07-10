--!strict
-- UI sound packs. Each pack maps abstract UI events (Hover/Click/Open/Close/
-- Success/Error) to a sound + volume + pitch. Like themes and layout packs,
-- sound packs are swappable at runtime and orthogonal to everything else.
--
-- All sounds use Roblox's built-in rbxasset://sounds/* set, so the template
-- makes noise with zero uploaded assets. Distinct pack "feels" come from
-- varying the sound choice, pitch (PlaybackSpeed) and volume — add a pack by
-- appending here; add an event by adding a key to each pack.

local UISoundConfig = {}

export type SoundDef = { id: string, volume: number, pitch: number }
export type SoundPack = {
	Id: string,
	DisplayName: string,
	Events: { [string]: SoundDef },
}

-- Verified-loading built-in sounds (checked in Studio).
local PING = "rbxasset://sounds/electronicpingshort.wav"
local SWITCH = "rbxasset://sounds/switch.wav"
local SWITCH3 = "rbxasset://sounds/switch3.wav"
local CLICK = "rbxasset://sounds/clickfast.wav"
local BASS = "rbxasset://sounds/bass.wav"
local SNAP = "rbxasset://sounds/snap.wav"

UISoundConfig.DefaultPackId = "Clean"

UISoundConfig.Packs = {
	-- Subtle, modern: soft clicks and gentle pings.
	{
		Id = "Clean",
		DisplayName = "Clean",
		Events = {
			Hover = { id = SWITCH, volume = 0.12, pitch = 1.6 },
			Click = { id = CLICK, volume = 0.35, pitch = 1.1 },
			Open = { id = SWITCH3, volume = 0.3, pitch = 1.0 },
			Close = { id = SWITCH3, volume = 0.3, pitch = 0.85 },
			Success = { id = PING, volume = 0.4, pitch = 1.2 },
			Error = { id = BASS, volume = 0.4, pitch = 0.9 },
		},
	},
	-- Punchy, higher-pitched, game-y.
	{
		Id = "Arcade",
		DisplayName = "Arcade",
		Events = {
			Hover = { id = SNAP, volume = 0.15, pitch = 1.8 },
			Click = { id = SNAP, volume = 0.45, pitch = 1.3 },
			Open = { id = PING, volume = 0.4, pitch = 1.5 },
			Close = { id = PING, volume = 0.35, pitch = 1.0 },
			Success = { id = PING, volume = 0.5, pitch = 1.7 },
			Error = { id = BASS, volume = 0.5, pitch = 0.7 },
		},
	},
	-- Silent pack — drop-in mute without touching call sites.
	{
		Id = "Muted",
		DisplayName = "Muted",
		Events = {},
	},
} :: { SoundPack }

function UISoundConfig.GetById(id: string): SoundPack?
	for _, pack in UISoundConfig.Packs do
		if pack.Id == id then
			return pack
		end
	end
	return nil
end

return UISoundConfig

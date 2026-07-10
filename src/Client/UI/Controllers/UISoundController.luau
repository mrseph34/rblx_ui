--!strict
-- Plays UI sounds by abstract event name from the active sound pack. One pooled
-- Sound instance per event is reused (re-fired via :Play()), so there's no
-- per-click allocation. Injected into the component base so buttons can play
-- Hover/Click with no direct dependency; screens call Open/Close/Success/Error.
--
-- Swapping packs (SetPack) just re-points the pooled sounds — call sites never
-- change. The "Muted" pack yields no sounds without any special-casing.

local SoundService = game:GetService("SoundService")

local UISoundConfig = require(script.Parent.Parent.Config.UISoundConfig)

local UISoundController = {}
UISoundController.__index = UISoundController

function UISoundController.new(packId: string?)
	local self = setmetatable({}, UISoundController)
	self._folder = Instance.new("Folder")
	self._folder.Name = "UISounds"
	self._folder.Parent = SoundService
	self._sounds = {} :: { [string]: Sound }
	self._pack = nil :: any
	self:SetPack(packId or UISoundConfig.DefaultPackId)
	return self
end

-- Build/refresh one pooled Sound per event for the chosen pack.
function UISoundController:SetPack(packId: string)
	local pack = UISoundConfig.GetById(packId)
	if not pack then
		return
	end
	self._pack = pack
	for _, sound in self._sounds do
		sound:Destroy()
	end
	self._sounds = {}
	for event, def in pack.Events do
		local sound = Instance.new("Sound")
		sound.Name = event
		sound.SoundId = def.id
		sound.Volume = def.volume
		sound.PlaybackSpeed = def.pitch
		sound.Parent = self._folder
		self._sounds[event] = sound
	end
end

function UISoundController:GetPackId(): string
	return self._pack and self._pack.Id or "Muted"
end

-- Play a UI event sound. Unknown events / the Muted pack are silent no-ops.
function UISoundController:Play(event: string)
	local sound = self._sounds[event]
	if sound then
		-- Restart so rapid repeats (fast clicks) always retrigger.
		sound.TimePosition = 0
		sound:Play()
	end
end

return UISoundController

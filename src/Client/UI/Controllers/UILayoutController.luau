--!strict
-- Owns the active on-screen LAYOUT preset (nav rail placement + HUD regions) and
-- applies it live. Decoupled from the pack/theme controllers: a layout preset
-- only moves pieces around the screen, so switching one never touches the theme
-- or the shop's data arrangement.
--
-- ClientHandler injects the HUD screen and a nav-rebuild callback; the Theme
-- Editor's Layout picker and the Studio UIDebug seam both drive Apply(). When no
-- preset is active the nav rail falls back to the active pack's own Nav settings,
-- so this layers cleanly on top of the existing pack-driven placement.

local LayoutPresetConfig = require(script.Parent.Parent.Config.LayoutPresetConfig)
local NavConfig = require(script.Parent.Parent.Config.NavConfig)
local UISignal = require(script.Parent.Parent.UISignal)

local UILayoutController = {}
UILayoutController.__index = UILayoutController

function UILayoutController.new(hud: any)
	local self = setmetatable({}, UILayoutController)
	self._hud = hud
	self._active = nil :: LayoutPresetConfig.LayoutPreset?
	self._rebuildNav = nil :: (() -> ())?
	self.Changed = UISignal.new()
	return self
end

-- ClientHandler wires this so Apply() can trigger a nav rail rebuild.
function UILayoutController:SetNavRebuilder(fn: () -> ())
	self._rebuildNav = fn
end

function UILayoutController:GetActive(): LayoutPresetConfig.LayoutPreset?
	return self._active
end

function UILayoutController:GetActiveId(): string?
	return self._active and self._active.id or nil
end

-- The nav geometry the rail should build with right now: the active preset's
-- nav block, or (no preset) the pack's own Nav plus the NavConfig globals.
function UILayoutController:GetNavGeometry(packNav: any): LayoutPresetConfig.NavLayout
	if self._active then
		return self._active.nav
	end
	return {
		side = packNav.Side,
		vertical = packNav.Vertical,
		fill = NavConfig.FillDirection,
		showLabels = NavConfig.ShowLabels,
	}
end

-- Apply a preset by id: relayout the HUD (money region, any per-element region
-- overrides, optional scale) in one rebuild, then rebuild the nav rail in its
-- new spot. Returns true if the id resolved to a real preset.
function UILayoutController:Apply(presetId: string): boolean
	local preset = LayoutPresetConfig.Get(presetId)
	if not preset then
		return false
	end
	self._active = preset
	if self._hud then
		self._hud:ApplyLayout({
			money = preset.hud.money,
			regions = preset.hud.regions,
			scaleOverride = preset.hud.scale,
		})
	end
	if self._rebuildNav then
		self._rebuildNav()
	end
	self.Changed:Fire(preset)
	return true
end

return UILayoutController

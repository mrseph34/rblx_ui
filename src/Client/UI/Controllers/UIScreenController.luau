--!strict
-- Owns the screen registry and the single modal slot; decides what's visible
-- and animates transitions. Screens register themselves (id -> screen module
-- instance); the controller calls their Show/Hide/Update. It never builds Gui
-- itself — that's the screens' job — it just orchestrates them.
--
-- Also holds the highlight-target registry the tutorial uses: any screen can
-- publish "here is the GuiObject for nav.shop", and the tutorial asks for it by
-- id to point its spotlight, keeping tutorial data decoupled from layout.

local UISignal = require(script.Parent.Parent.UISignal)

local UIScreenController = {}
UIScreenController.__index = UIScreenController

-- Panel screens that own the centre of the screen: only ONE may be open at a
-- time, so opening any of these first closes whichever other one is up. This is
-- the "open a new menu -> the previous one closes" consistency. The modal slot,
-- HUD, chat bar and toasts are NOT in this set (they layer independently).
local EXCLUSIVE_PANELS = {
	shop = true,
	store = true,
	index = true,
	themeSelector = true,
	settings = true,
	npcDialog = true,
	tutorial = true,
}

function UIScreenController.new(themeController: any)
	local self = setmetatable({}, UIScreenController)
	self._themeController = themeController
	self._screens = {} :: { [string]: any }
	self._visible = {} :: { [string]: boolean }
	self._highlightTargets = {} :: { [string]: GuiObject }
	self._modalScreenId = nil :: string?
	self.ScreenShown = UISignal.new()
	self.ScreenHidden = UISignal.new()
	return self
end

function UIScreenController:RegisterScreen(id: string, screen: any)
	self._screens[id] = screen
	if screen.SetControllers then
		screen:SetControllers(self._themeController, self)
	end
end

-- Nominate which registered screen acts as the modal host (ModalScreen).
function UIScreenController:SetModalScreen(id: string)
	self._modalScreenId = id
end

function UIScreenController:GetScreen(id: string): any
	return self._screens[id]
end

function UIScreenController:IsVisible(id: string): boolean
	return self._visible[id] == true
end

function UIScreenController:ShowScreen(id: string, data: any?)
	local screen = self._screens[id]
	if not screen then
		warn("[UIScreenController] Unknown screen: " .. id)
		return
	end
	-- Single-panel rule: opening one exclusive panel closes any other open one,
	-- so its outro (reverse animation) plays as the new panel animates in.
	if EXCLUSIVE_PANELS[id] then
		for otherId in EXCLUSIVE_PANELS do
			if otherId ~= id and self._visible[otherId] then
				self:HideScreen(otherId)
			end
		end
	end
	self._visible[id] = true
	screen:Show(data)
	self.ScreenShown:Fire(id)
end

function UIScreenController:HideScreen(id: string)
	local screen = self._screens[id]
	if not screen or not self._visible[id] then
		return
	end
	self._visible[id] = false
	screen:Hide()
	self.ScreenHidden:Fire(id)
end

function UIScreenController:ToggleScreen(id: string, data: any?)
	if self._visible[id] then
		self:HideScreen(id)
	else
		self:ShowScreen(id, data)
	end
end

function UIScreenController:UpdateScreen(id: string, data: any)
	local screen = self._screens[id]
	if screen and screen.Update then
		screen:Update(data)
	end
end

-- ---- modal slot -------------------------------------------------------

function UIScreenController:ShowModal(modalData: any)
	if not self._modalScreenId then
		warn("[UIScreenController] No modal screen registered")
		return
	end
	self:ShowScreen(self._modalScreenId, modalData)
end

function UIScreenController:HideModal()
	if self._modalScreenId then
		self:HideScreen(self._modalScreenId)
	end
end

-- ---- highlight targets (tutorial) -------------------------------------

function UIScreenController:RegisterHighlightTarget(id: string, guiObject: GuiObject)
	self._highlightTargets[id] = guiObject
end

function UIScreenController:GetHighlightTarget(id: string): GuiObject?
	return self._highlightTargets[id]
end

-- Hide whichever non-persistent screen is on top; used by the CloseTop action.
-- Returns true if something was closed.
function UIScreenController:CloseTopmost(): boolean
	if self._modalScreenId and self._visible[self._modalScreenId] then
		self:HideModal()
		return true
	end
	-- Close panels in a sensible priority order.
	for _, id in { "themeSelector", "store", "shop", "index", "settings", "tutorial" } do
		if self._visible[id] then
			self:HideScreen(id)
			return true
		end
	end
	return false
end

return UIScreenController

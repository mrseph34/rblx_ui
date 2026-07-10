--!strict
-- The one client LocalScript. Boots the UI system in a controlled order,
-- injects controllers into components/screens, registers every screen, wires
-- input actions, and kicks off a demo: HUD + a nav rail + tutorial, with the
-- shop and Theme Editor reachable by button or hotkey.
--
-- Adding a screen = require it, construct it, RegisterScreen it here. Adding a
-- theme or pack = drop a module and register in config; no change here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = script.Parent.UI
local Components = UI.Components
local Screens = UI.Screens
local Controllers = UI.Controllers

-- Config / shared.
local DevConfig = require(UI.Config.DevConfig)
local HUDConfig = require(UI.Config.HUDConfig)
local NavConfig = require(UI.Config.NavConfig)
local TutorialConfig = require(UI.Config.TutorialConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SharedTypes = require(ReplicatedStorage.Shared.Types)

-- Component base (for dependency injection) + styler for the nav rail.
local UIComponentBase = require(Components.UIComponentBase)
local UIButtonComponent = require(Components.UIButtonComponent)
local UIStyler = require(UI.UIStyler)

-- Controllers.
local UIThemeController = require(Controllers.UIThemeController)
local UIScreenController = require(Controllers.UIScreenController)
local UIInputController = require(Controllers.UIInputController)
local UISoundController = require(Controllers.UISoundController)
local UIOverheadController = require(Controllers.UIOverheadController)

-- Screens.
local GameHUDScreen = require(Screens.GameHUDScreen)
local ShopScreen = require(Screens.ShopScreen)
local ModalScreen = require(Screens.ModalScreen)
local TutorialScreen = require(Screens.TutorialScreen)
local ThemeSelectorScreen = require(Screens.ThemeSelectorScreen)
local NPCDialogScreen = require(Screens.NPCDialogScreen)

local player = Players.LocalPlayer

-- ---- boot controllers -------------------------------------------------

local themeController = UIThemeController.new()
local screenController = UIScreenController.new(themeController)
local inputController = UIInputController.new()
local soundController = UISoundController.new()
local overheadController = UIOverheadController.new(themeController)

-- Inject controllers into the component base: theme = live re-skinning; sound =
-- hover/click SFX. Both are nil-safe so components work without them.
UIComponentBase.SetThemeController(themeController)
UIComponentBase.SetSoundController(soundController)
require(Screens.UIScreenBase).SetSoundController(soundController)

-- Screen open/close SFX, wired centrally so no screen needs sound code.
screenController.ScreenShown:Connect(function(id: string)
	if id ~= "hud" then
		soundController:Play("Open")
	end
end)
screenController.ScreenHidden:Connect(function(id: string)
	if id ~= "hud" then
		soundController:Play("Close")
	end
end)

-- ---- register screens -------------------------------------------------

local hud = GameHUDScreen.new()
local shop = ShopScreen.new()
local modal = ModalScreen.new()
local tutorial = TutorialScreen.new()
local themeSelector = ThemeSelectorScreen.new()
local npcDialog = NPCDialogScreen.new()

screenController:RegisterScreen("hud", hud)
screenController:RegisterScreen("shop", shop)
screenController:RegisterScreen("modal", modal)
screenController:RegisterScreen("tutorial", tutorial)
screenController:RegisterScreen("themeSelector", themeSelector)
screenController:RegisterScreen("npcDialog", npcDialog)
screenController:SetModalScreen("modal")

-- ---- purchase wiring (client -> server) -------------------------------

local purchaseRemote = Remotes.WaitFor("PurchaseItem", 5) :: RemoteFunction?
local currencyChanged = Remotes.WaitFor("CurrencyChanged", 5) :: RemoteEvent?

-- Injected into the shop: authoritative purchase with a local fallback so the
-- shop still works in a UI-only / test place where the server isn't present.
shop:SetPurchaseHandler(function(item: SharedTypes.ShopItem): SharedTypes.PurchaseResult
	if purchaseRemote then
		local ok, result = pcall(function()
			return purchaseRemote:InvokeServer(item.id)
		end)
		if ok and typeof(result) == "table" then
			return result
		end
	end
	-- Local fallback (offline preview).
	return { success = true, messageKey = "shop.purchase_success" }
end)

if currencyChanged then
	currencyChanged.OnClientEvent:Connect(function(balances: SharedTypes.CurrencyBalances)
		hud:Update({ values = balances })
		shop:Update({ balances = balances })
	end)
end

-- ---- floating nav rail (dev/demo) -------------------------------------

-- Maps a NavConfig button `action` to what it does. Adding a nav button is a
-- data edit in NavConfig plus (if it's a new action) one row here.
local function navAction(action: string)
	if action == "ToggleShop" then
		screenController:ToggleScreen("shop", { balances = shop._balances })
	elseif action == "ToggleThemeEditor" then
		screenController:ToggleScreen("themeSelector")
	elseif action == "ShowTutorial" then
		screenController:ShowScreen("tutorial", {
			steps = TutorialConfig.Steps,
			onComplete = function() end,
		})
	end
end

local function buildNavRail()
	if not DevConfig.ShowNavRail then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "NavRail"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Position the rail per the active pack (side + vertical anchor), so packs
	-- can move the side buttons for a different feel; geometry comes from NavConfig.
	local nav = themeController:GetPack().Nav
	local horizontal = NavConfig.FillDirection == "Horizontal"
	local onRight = nav.Side == "Right"
	local vAnchor = nav.Vertical == "Top" and 0 or (nav.Vertical == "Bottom" and 1 or 0.5)
	local vPos = nav.Vertical == "Top" and 0.14 or (nav.Vertical == "Bottom" and 0.86 or 0.5)
	local edge = NavConfig.EdgeOffset

	local rail = UIStyler.Frame("Rail")
	rail.BackgroundTransparency = 1
	rail.AnchorPoint = Vector2.new(onRight and 1 or 0, vAnchor)
	rail.Position = UDim2.new(onRight and 1 or 0, onRight and -edge or edge, vPos, 0)
	rail.Size = UDim2.fromOffset(NavConfig.ButtonSize.X + 16, 300)
	rail.AutomaticSize = Enum.AutomaticSize.XY
	UIStyler.ListLayout({
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, NavConfig.Spacing),
		VerticalAlignment = vAnchor == 1 and Enum.VerticalAlignment.Bottom or Enum.VerticalAlignment.Top,
	}).Parent = rail
	rail.Parent = gui

	local order = 0
	for _, def in NavConfig.Buttons do
		if def.authorizedOnly and not DevConfig.IsAuthorized(player.UserId) then
			continue
		end
		order += 1
		local size = def.size or NavConfig.ButtonSize
		local button = UIButtonComponent.new()
		button:Create(rail, {
			icon = def.icon,
			variant = def.variant or "Primary",
			size = UDim2.fromOffset(size.X, size.Y),
			layoutOrder = order,
			onClick = function()
				navAction(def.action)
			end,
		})
		screenController:RegisterHighlightTarget(def.id, button.Root)
	end
end

-- ---- input actions ----------------------------------------------------

inputController:BindAction("ToggleShop", function()
	screenController:ToggleScreen("shop", { balances = shop._balances })
end)
inputController:BindAction("ToggleThemeEditor", function()
	if DevConfig.IsAuthorized(player.UserId) then
		screenController:ToggleScreen("themeSelector")
	end
end)
inputController:BindAction("ToggleHUD", function()
	screenController:ToggleScreen("hud")
end)
inputController:BindAction("CloseTop", function()
	screenController:CloseTopmost()
end)
inputController:BindAction("AdvanceTutorial", function()
	if screenController:IsVisible("tutorial") then
		tutorial:Advance()
	end
end)

-- ---- launch -----------------------------------------------------------

-- HUD is always on; seed it with config defaults + sample objectives.
screenController:ShowScreen("hud", {
	values = HUDConfig.DefaultValues,
	objectives = {
		{ id = "reach_shop", textKey = "objective.reach_shop", done = true },
		{ id = "buy_boost", textKey = "objective.buy_boost", done = false },
		{ id = "survive", textKey = "objective.survive", done = false },
	},
})

buildNavRail()

-- Studio-only debug seam. Exposed via BindableFunctions in ReplicatedStorage
-- (not _G, which is not shared with externally-injected code) so the MCP
-- screenshot harness (tools/ui-shots.lua) can drive theme/pack/screen switches
-- at runtime. Never present in a live game (guarded by IsStudio).
if game:GetService("RunService"):IsStudio() then
	local function rebuildNav()
		local existing = player.PlayerGui:FindFirstChild("NavRail")
		if existing then
			existing:Destroy()
		end
		buildNavRail()
	end
	local function applyPack(packId: string)
		themeController:SetPack(packId)
		rebuildNav()
		hud:Rebuild()
		if screenController:IsVisible("shop") then
			screenController:GetScreen("shop"):_RenderItems()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "UIDebug"
	local function bind(name: string, fn: (...any) -> ...any)
		local bindable = Instance.new("BindableFunction")
		bindable.Name = name
		bindable.OnInvoke = fn
		bindable.Parent = folder
	end
	bind("ApplyPack", function(packId: string)
		applyPack(packId)
		return true
	end)
	bind("SetTheme", function(themeId: string)
		themeController:SetTheme(themeId)
		return true
	end)
	bind("ShowScreen", function(id: string)
		if id == "shop" then
			screenController:ShowScreen("shop", { balances = shop._balances })
		else
			screenController:ShowScreen(id)
		end
		return true
	end)
	bind("HideScreen", function(id: string)
		screenController:HideScreen(id)
		return true
	end)
	bind("SelectCategory", function(categoryId: string)
		if screenController:IsVisible("shop") then
			screenController:GetScreen("shop"):_SelectCategory(categoryId)
		end
		return true
	end)
	bind("SetSoundPack", function(packId: string)
		soundController:SetPack(packId)
		return true
	end)
	bind("SetElementRegion", function(elementId: string, region: string)
		hud:SetElementRegion(elementId, region)
		return true
	end)
	bind("ShowDialog", function()
		screenController:ShowScreen("npcDialog", { sequenceId = "welcome_merchant" })
		return true
	end)
	bind("ShowBanner", function(variant: string)
		hud:PushBanner({
			titleKey = variant == "Achievement" and "notify.achievement.title" or "notify.levelup.title",
			bodyKey = variant == "Achievement" and "notify.achievement.body" or "notify.levelup.body",
			variant = variant or "LevelUp",
			duration = 4,
		})
		return true
	end)
	bind("SetOverheadLocation", function(locationId: string)
		if player.Character then
			overheadController:SetLocation(player.Character, locationId)
		end
		return true
	end)
	folder.Parent = ReplicatedStorage
end

-- ---- overhead billboard (demo on the local player) -------------------

-- Attach a themed nameplate + vitals bars above the local character's head and
-- keep them in sync with the HUD values, so the overhead UI is visible in-play.
-- A game would call these for every player/NPC/mob it wants a plate on.
local function attachOwnOverhead(character: Model)
	overheadController:Attach(character, { name = player.DisplayName, level = HUDConfig.DefaultValues.level })
	overheadController:SetValues(character, {
		health = HUDConfig.DefaultValues.health,
		mana = HUDConfig.DefaultValues.mana,
	})
end
if player.Character then
	attachOwnOverhead(player.Character)
end
player.CharacterAdded:Connect(attachOwnOverhead)

-- Live-ticking timer to show HUD updates working.
task.spawn(function()
	local timer = HUDConfig.DefaultValues.timer
	while true do
		task.wait(1)
		timer = timer > 0 and timer - 1 or 90
		hud:Update({ values = { timer = timer } })
	end
end)

-- Kick off onboarding on join.
if DevConfig.AutoStartTutorial then
	task.delay(1, function()
		screenController:ShowScreen("tutorial", {
			steps = TutorialConfig.Steps,
			onComplete = function()
				hud:PushToast({ text = "Tutorial complete! Press B for the shop, T for the Theme Editor.", variant = "Success", duration = 5 })
			end,
		})
	end)
end

print("[ClientHandler] rblx_ui client booted — themes:", #themeController:GetThemeList(), "packs:", #themeController:GetPackList())

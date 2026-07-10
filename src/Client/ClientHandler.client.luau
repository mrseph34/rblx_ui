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

-- Screens.
local GameHUDScreen = require(Screens.GameHUDScreen)
local ShopScreen = require(Screens.ShopScreen)
local ModalScreen = require(Screens.ModalScreen)
local TutorialScreen = require(Screens.TutorialScreen)
local ThemeSelectorScreen = require(Screens.ThemeSelectorScreen)

local player = Players.LocalPlayer

-- ---- boot controllers -------------------------------------------------

local themeController = UIThemeController.new()
local screenController = UIScreenController.new(themeController)
local inputController = UIInputController.new()

-- Inject the theme controller into the component base so every component that
-- gets built auto-registers for live theme updates.
UIComponentBase.SetThemeController(themeController)

-- ---- register screens -------------------------------------------------

local hud = GameHUDScreen.new()
local shop = ShopScreen.new()
local modal = ModalScreen.new()
local tutorial = TutorialScreen.new()
local themeSelector = ThemeSelectorScreen.new()

screenController:RegisterScreen("hud", hud)
screenController:RegisterScreen("shop", shop)
screenController:RegisterScreen("modal", modal)
screenController:RegisterScreen("tutorial", tutorial)
screenController:RegisterScreen("themeSelector", themeSelector)
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

	local rail = UIStyler.Frame("Rail")
	rail.BackgroundTransparency = 1
	rail.AnchorPoint = Vector2.new(0, 0.5)
	rail.Position = UDim2.new(0, 12, 0.5, 0)
	rail.Size = UDim2.fromOffset(64, 220)
	UIStyler.ListLayout({ Padding = UDim.new(0, 10) }).Parent = rail
	rail.Parent = gui

	local function railButton(icon: string, order: number, onClick: () -> (), targetId: string?)
		local button = UIButtonComponent.new()
		button:Create(rail, {
			icon = icon,
			variant = "Primary",
			size = UDim2.fromOffset(56, 56),
			layoutOrder = order,
			onClick = onClick,
		})
		if targetId then
			screenController:RegisterHighlightTarget(targetId, button.Root)
		end
		return button
	end

	railButton("🛒", 1, function()
		screenController:ToggleScreen("shop", { balances = shop._balances })
	end, "nav.shop")

	if DevConfig.IsAuthorized(player.UserId) then
		railButton("🎨", 2, function()
			screenController:ToggleScreen("themeSelector")
		end, "nav.theme")
	end

	railButton("❓", 3, function()
		screenController:ShowScreen("tutorial", {
			steps = TutorialConfig.Steps,
			onComplete = function() end,
		})
	end)
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

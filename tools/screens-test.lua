-- Secondary smoke test: constructs every screen and drives Show/Update/Hide
-- with sample data, against a synthetic PlayerGui, to catch build-time errors
-- in the screen modules that the module-level smoke test doesn't reach.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

local passed, failed = 0, 0
local function check(name, ok, detail)
	if ok then
		passed += 1
		print("  [PASS] " .. name)
	else
		failed += 1
		warn("  [FAIL] " .. name .. (detail and (" — " .. tostring(detail)) or ""))
	end
end

-- run-in-roblox has no real players; make a fake LocalPlayer with a PlayerGui
-- so screens can parent their ScreenGuis somewhere.
if not Players.LocalPlayer then
	-- In Studio-run context LocalPlayer may be nil; create a stand-in container.
	local fakeGui = Instance.new("ScreenGui")
	fakeGui.Name = "PlayerGui"
	fakeGui.Parent = game:GetService("CoreGui")
end

local UI = StarterPlayer.StarterPlayerScripts.ClientHandler.UI

local UIComponentBase = require(UI.Components.UIComponentBase)
local UIThemeController = require(UI.Controllers.UIThemeController)
local UIScreenController = require(UI.Controllers.UIScreenController)

local themeController = UIThemeController.new()
local screenController = UIScreenController.new(themeController)
UIComponentBase.SetThemeController(themeController)

print("== rblx_ui screens test ==")

-- Redirect screen guis to CoreGui when there's no PlayerGui.
local function parentGui(screen)
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	screen.Gui.Parent = playerGui or game:GetService("CoreGui")
end

local GameHUDScreen = require(UI.Screens.GameHUDScreen)
local ShopScreen = require(UI.Screens.ShopScreen)
local ModalScreen = require(UI.Screens.ModalScreen)
local TutorialScreen = require(UI.Screens.TutorialScreen)
local ThemeSelectorScreen = require(UI.Screens.ThemeSelectorScreen)

local hud = GameHUDScreen.new()
local shop = ShopScreen.new()
local modal = ModalScreen.new()
local tutorial = TutorialScreen.new()
local selector = ThemeSelectorScreen.new()

screenController:RegisterScreen("hud", hud)
screenController:RegisterScreen("shop", shop)
screenController:RegisterScreen("modal", modal)
screenController:RegisterScreen("tutorial", tutorial)
screenController:RegisterScreen("themeSelector", selector)
screenController:SetModalScreen("modal")

for _, screen in { hud, shop, modal, tutorial, selector } do
	parentGui(screen)
end

shop:SetPurchaseHandler(function()
	return { success = true, messageKey = "shop.purchase_success", balances = { Coins = 100, Gems = 100 } }
end)

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)

check("HUD show + update", pcall(function()
	screenController:ShowScreen("hud", {
		values = { coins = 500, gems = 40, wave = 2, timer = 75, health = 80, level = 9 },
		objectives = { { id = "a", text = "Do a thing", done = false } },
	})
	hud:Update({ values = { timer = 60 } })
	hud:PushToast({ text = "Hello", variant = "Info", duration = 0.2 })
end))

check("Shop show + render + category switch", pcall(function()
	screenController:ShowScreen("shop", { balances = ShopConfig.StartingBalances })
	shop:_SelectCategory("boosts")
	shop:_SelectCategory("cosmetics")
end))

check("Modal show (confirm)", pcall(function()
	screenController:ShowModal({ kind = "Confirm", title = "T", body = "B", onConfirm = function() end })
	screenController:HideModal()
end))

check("Tutorial run through all steps", pcall(function()
	screenController:ShowScreen("tutorial", { steps = require(UI.Config.TutorialConfig).Steps, onComplete = function() end })
	tutorial:Advance()
	tutorial:Advance()
	tutorial:Advance()
end))

check("Theme selector show + live edit + export", pcall(function()
	screenController:ShowScreen("themeSelector")
	selector:_LoadWorking(themeController:GetTheme(), true)
	-- Simulate an edit and export.
	selector._working.Colors.Primary = Color3.fromRGB(10, 20, 30)
	selector:_ApplyWorking()
	selector:_Export()
	assert(#selector._exportBox.Text > 100, "export box empty")
end))

check("Theme selector import round-trip", pcall(function()
	local ThemeSerializer = require(UI.Themes.ThemeSerializer)
	local src = ThemeSerializer.Serialize(require(UI.Themes.RusticTheme))
	selector._importBox.Text = src
	selector:_TryApplyImport()
	assert(themeController:GetTheme().Colors.Primary ~= nil, "import did not apply")
end))

check("Live theme swap re-skins open screens", pcall(function()
	themeController:SetTheme("Cartoon")
	task.wait()
	themeController:SetTheme("SciFi")
	task.wait()
	themeController:SetPack("Premium")
	shop:_RenderItems()
end))

check("Hide all screens", pcall(function()
	for _, id in { "hud", "shop", "tutorial", "themeSelector" } do
		screenController:HideScreen(id)
	end
end))

print(string.format("== %d passed, %d failed ==", passed, failed))
if failed > 0 then
	error("screens test FAILED")
end
print("screens test PASSED")

-- Headless smoke test for the rblx_ui pack. Run via tools/run-test.sh. Boots
-- inside a Rojo-built place and exercises the parts that must work without a
-- real player GUI:
--   * config sanity (shop items, categories, currencies)
--   * theme registry (all four themes load with a complete token set)
--   * ThemeSerializer round-trip (the Export/Import feature) — the headline
--   * controller logic (register/switch theme, screen registry)
--   * component construction (a button + card build without erroring)
--
-- Prints a PASS/FAIL summary and errors out (non-zero) on any failure so CI /
-- the terminal can tell.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local passed, failed = 0, 0
local function check(name, condition, detail)
	if condition then
		passed += 1
		print(string.format("  [PASS] %s", name))
	else
		failed += 1
		warn(string.format("  [FAIL] %s%s", name, detail and (" — " .. tostring(detail)) or ""))
	end
end

local UI = StarterPlayer.StarterPlayerScripts.ClientHandler.UI
local Shared = ReplicatedStorage.Shared

print("== rblx_ui smoke test ==")

-- ---- Shared config ----------------------------------------------------
print("[Shared config]")
local ShopConfig = require(Shared.Config.ShopConfig)
check("shop has items", #ShopConfig.Items > 0)
check("shop has categories", #ShopConfig.Categories > 0)
check("featured category resolves items", #ShopConfig.GetItemsForCategory("featured") > 0)
check("price formatting", ShopConfig.FormatPrice(1234567) == "1,234,567", ShopConfig.FormatPrice(1234567))
check("GetItemById works", ShopConfig.GetItemById("speed_cola") ~= nil)
check("CanAfford true when rich", ShopConfig.CanAfford({ Coins = 9999, Gems = 9999 }, ShopConfig.Items[1]))

-- ---- Themes -----------------------------------------------------------
print("[Themes]")
local UIThemeConfig = require(UI.Config.UIThemeConfig)
check("four themes registered", #UIThemeConfig.Themes == 4, #UIThemeConfig.Themes)
local requiredColorTokens = {
	"Primary", "Secondary", "Accent", "Background", "Surface", "SurfaceRaised",
	"Success", "Warning", "Error", "TextPrimary", "TextSecondary", "TextOnPrimary",
	"Stroke", "Overlay", "Disabled",
}
for _, theme in UIThemeConfig.Themes do
	local complete = true
	for _, token in requiredColorTokens do
		if typeof(theme.Colors[token]) ~= "Color3" then
			complete = false
			break
		end
	end
	check("theme '" .. theme.Id .. "' has all color tokens", complete)
	check("theme '" .. theme.Id .. "' has animations", typeof(theme.Animations.ThemeSwap) == "TweenInfo")
end

-- ---- Serializer round-trip (the Export/Import feature) ----------------
print("[ThemeSerializer round-trip]")
local ThemeSerializer = require(UI.Themes.ThemeSerializer)
local CartoonTheme = require(UI.Themes.CartoonTheme)

local source = ThemeSerializer.Serialize(CartoonTheme)
check("serialize produces non-empty source", #source > 100)
check("source looks like a module", string.find(source, "return") ~= nil and string.find(source, "Types.UITheme") ~= nil)

local restored, err = ThemeSerializer.Deserialize(source, require(UI.Themes.DefaultTheme))
check("deserialize succeeds", restored ~= nil, err)
if restored then
	local function colorEq(a, b)
		return math.abs(a.R - b.R) < 0.01 and math.abs(a.G - b.G) < 0.01 and math.abs(a.B - b.B) < 0.01
	end
	check("round-trip preserves Primary color", colorEq(restored.Colors.Primary, CartoonTheme.Colors.Primary))
	check("round-trip preserves Accent color", colorEq(restored.Colors.Accent, CartoonTheme.Colors.Accent))
	check("round-trip preserves Radii.Large", restored.Radii.Large == CartoonTheme.Radii.Large, restored.Radii.Large)
	check("round-trip preserves HoverScale", math.abs(restored.Effects.HoverScale - CartoonTheme.Effects.HoverScale) < 0.001)
	check("round-trip preserves Appear tween time", math.abs(restored.Animations.Appear.Time - CartoonTheme.Animations.Appear.Time) < 0.001)
	check("round-trip preserves font family", restored.Fonts.Title.Family == CartoonTheme.Fonts.Title.Family, restored.Fonts.Title.Family)
end

-- Deserialize garbage should fail gracefully.
local bad = ThemeSerializer.Deserialize("not a theme at all", require(UI.Themes.DefaultTheme))
check("deserialize rejects garbage", bad == nil)

-- ---- Controllers ------------------------------------------------------
print("[Controllers]")
local UIThemeController = require(UI.Controllers.UIThemeController)
local controller = UIThemeController.new()
check("controller defaults to a theme", controller:GetTheme() ~= nil)
check("controller lists themes", #controller:GetThemeList() == 4)

-- Register a fake component and confirm SetTheme pushes to it.
local applied = { count = 0, last = nil }
local fakeComponent = {
	ApplyTheme = function(_self, theme)
		applied.count += 1
		applied.last = theme
	end,
}
controller:RegisterComponent(fakeComponent)
controller:SetTheme("SciFi")
task.wait() -- ApplyThemeObject spawns per-component
check("SetTheme applied to registered component", applied.count >= 1, applied.count)
check("SetTheme switched current theme", controller:GetTheme().Id == "SciFi", controller:GetTheme().Id)

-- Runtime theme upsert (import path). A distinct id grows the list; re-adding
-- the same id replaces in place (no duplicate).
restored.Id = "Imported"
restored.DisplayName = "Imported"
controller:UpsertRuntimeTheme(restored)
check("new runtime theme registered", #controller:GetThemeList() == 5, #controller:GetThemeList())
controller:UpsertRuntimeTheme(restored)
check("re-upsert same id dedups", #controller:GetThemeList() == 5, #controller:GetThemeList())
check("runtime theme selectable by id", (function()
	controller:SetTheme("Imported")
	return controller:GetTheme().Id == "Imported"
end)())

-- Pack switching.
controller:SetPack("Compact")
check("pack switched", controller:GetPack().Id == "Compact", controller:GetPack().Id)

-- ---- Components build --------------------------------------------------
print("[Components]")
local UIComponentBase = require(UI.Components.UIComponentBase)
UIComponentBase.SetThemeController(controller)

local ok, buildErr = pcall(function()
	local holder = Instance.new("Frame")
	local UIButtonComponent = require(UI.Components.UIButtonComponent)
	local button = UIButtonComponent.new()
	button:Create(holder, { text = "Test", variant = "Primary" })
	assert(button.Root:IsA("GuiObject"), "button root is not a GuiObject")

	local UICardComponent = require(UI.Components.UICardComponent)
	local card = UICardComponent.new()
	card:Create(holder, { item = ShopConfig.Items[1], currencyIcon = "🪙", affordable = true })
	assert(card.Root:IsA("GuiObject"), "card root is not a GuiObject")

	-- Live theme swap should re-style built components without erroring.
	controller:SetTheme("Cartoon")
	button:Destroy()
	card:Destroy()
end)
check("components build + theme-swap + destroy cleanly", ok, buildErr)

-- ---- Summary ----------------------------------------------------------
print(string.format("== %d passed, %d failed ==", passed, failed))
if failed > 0 then
	error(string.format("smoke test FAILED (%d failures)", failed))
end
print("smoke test PASSED")

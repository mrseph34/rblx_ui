--!strict
-- Single source of truth for everything sold in the shop: currencies,
-- categories, items and price helpers. The server validates purchases against
-- this module; the client renders from it. Tune the shop by editing data here
-- only — no gameplay script should hardcode an item or price.

local Types = require(script.Parent.Parent.Types)

local ShopConfig = {}

ShopConfig.StartingBalances = {
	Coins = 750,
	Gems = 120,
} :: Types.CurrencyBalances

ShopConfig.Currencies = {
	Coins = { id = "Coins", nameKey = "currency.coins", icon = "💰", colorToken = "Accent", order = 1 },
	Gems = { id = "Gems", nameKey = "currency.gems", icon = "💎", colorToken = "Secondary", order = 2 },
} :: { [string]: Types.CurrencyDef }

ShopConfig.Categories = {
	{ id = "featured", nameKey = "shop.category.featured", order = 1 },
	{ id = "boosts", nameKey = "shop.category.boosts", order = 2 },
	{ id = "cosmetics", nameKey = "shop.category.cosmetics", order = 3 },
} :: { Types.ShopCategory }

ShopConfig.Items = {
	-- Featured (a fuller set so grids fill several rows and scrolling is exercised)
	{ id = "starter_bundle", nameKey = "item.starter_bundle.name", descriptionKey = "item.starter_bundle.desc", iconId = "", price = 99, currencyType = "Coins", category = "featured", tags = { "Sale" } },
	{ id = "mega_bundle", nameKey = "item.mega_bundle.name", descriptionKey = "item.mega_bundle.desc", iconId = "", price = 120, currencyType = "Gems", category = "featured", tags = { "Popular", "Limited" } },
	{ id = "mystery_crate", nameKey = "item.mystery_crate.name", descriptionKey = "item.mystery_crate.desc", iconId = "", price = 500, currencyType = "Coins", category = "featured", tags = { "New" } },
	{ id = "value_pack", nameKey = "item.mega_bundle.name", descriptionKey = "item.mega_bundle.desc", iconId = "", price = 260, currencyType = "Coins", category = "featured", tags = { "Popular" } },
	{ id = "daily_deal", nameKey = "item.starter_bundle.name", descriptionKey = "item.starter_bundle.desc", iconId = "", price = 60, currencyType = "Coins", category = "featured", tags = { "Sale", "Limited" } },
	{ id = "legend_crate", nameKey = "item.mystery_crate.name", descriptionKey = "item.mystery_crate.desc", iconId = "", price = 900, currencyType = "Gems", category = "featured", tags = { "Rare" } },
	{ id = "coin_pouch", nameKey = "item.starter_bundle.name", descriptionKey = "item.starter_bundle.desc", iconId = "", price = 40, currencyType = "Coins", category = "featured" },
	{ id = "gem_chest", nameKey = "item.mega_bundle.name", descriptionKey = "item.mega_bundle.desc", iconId = "", price = 75, currencyType = "Gems", category = "featured", tags = { "New" } },
	{ id = "season_pass", nameKey = "item.mega_bundle.name", descriptionKey = "item.mega_bundle.desc", iconId = "", price = 480, currencyType = "Coins", category = "featured", tags = { "Popular", "New" } },
	{ id = "lucky_box", nameKey = "item.mystery_crate.name", descriptionKey = "item.mystery_crate.desc", iconId = "", price = 130, currencyType = "Coins", category = "featured", tags = { "Sale" } },
	{ id = "vip_bundle", nameKey = "item.mega_bundle.name", descriptionKey = "item.mega_bundle.desc", iconId = "", price = 640, currencyType = "Gems", category = "featured", tags = { "Rare", "Limited" } },
	{ id = "welcome_gift", nameKey = "item.starter_bundle.name", descriptionKey = "item.starter_bundle.desc", iconId = "", price = 20, currencyType = "Coins", category = "featured", tags = { "New" } },

	-- Boosts
	{ id = "speed_cola", nameKey = "item.speed_cola.name", descriptionKey = "item.speed_cola.desc", iconId = "", price = 150, currencyType = "Coins", category = "boosts", tags = { "New" } },
	{ id = "shield_generator", nameKey = "item.shield_generator.name", descriptionKey = "item.shield_generator.desc", iconId = "", price = 320, currencyType = "Coins", category = "boosts", tags = { "Popular" } },
	{ id = "double_xp", nameKey = "item.double_xp.name", descriptionKey = "item.double_xp.desc", iconId = "", price = 25, currencyType = "Gems", category = "boosts", tags = { "Limited" } },

	-- Cosmetics
	{ id = "golden_crown", nameKey = "item.golden_crown.name", descriptionKey = "item.golden_crown.desc", iconId = "", price = 90, currencyType = "Gems", category = "cosmetics", tags = { "Rare" } },
	{ id = "pixel_shades", nameKey = "item.pixel_shades.name", descriptionKey = "item.pixel_shades.desc", iconId = "", price = 220, currencyType = "Coins", category = "cosmetics" },
	{ id = "rainbow_trail", nameKey = "item.rainbow_trail.name", descriptionKey = "item.rainbow_trail.desc", iconId = "", price = 45, currencyType = "Gems", category = "cosmetics", tags = { "New", "Rare" } },
} :: { Types.ShopItem }

function ShopConfig.GetItemById(itemId: string): Types.ShopItem?
	for _, item in ShopConfig.Items do
		if item.id == itemId then
			return item
		end
	end
	return nil
end

function ShopConfig.GetItemsForCategory(categoryId: string): { Types.ShopItem }
	local items = {}
	for _, item in ShopConfig.Items do
		if item.category == categoryId then
			table.insert(items, item)
		end
	end
	return items
end

function ShopConfig.GetOrderedCategories(): { Types.ShopCategory }
	local categories = table.clone(ShopConfig.Categories)
	table.sort(categories, function(a, b)
		return a.order < b.order
	end)
	return categories
end

function ShopConfig.GetOrderedCurrencies(): { Types.CurrencyDef }
	local currencies = {}
	for _, currency in ShopConfig.Currencies do
		table.insert(currencies, currency)
	end
	table.sort(currencies, function(a, b)
		return a.order < b.order
	end)
	return currencies
end

-- "1234567" -> "1,234,567"
function ShopConfig.FormatPrice(amount: number): string
	local formatted = tostring(math.floor(amount))
	while true do
		local replaced
		formatted, replaced = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then
			break
		end
	end
	return formatted
end

function ShopConfig.CanAfford(balances: Types.CurrencyBalances, item: Types.ShopItem): boolean
	return (balances[item.currencyType] or 0) >= item.price
end

return ShopConfig

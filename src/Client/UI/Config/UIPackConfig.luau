--!strict
-- Layout packs: named bundles of *arrangement* choices, orthogonal to themes.
-- A theme decides how things look (colour/font/motion); a pack decides how the
-- same data is arranged — the entry focal point, grid vs list, and where the
-- currency + nav rail live. Any theme combines with any pack.
--
-- Each pack points its shop at an EntryLayoutConfig spec id, so the six packs
-- below reuse one renderer and stay mutually consistent. Add a pack by
-- appending here; add a new *look* by adding a spec in EntryLayoutConfig.

local Types = require(script.Parent.Parent.Types)

local UIPackConfig = {}

UIPackConfig.DefaultPackId = "Default"

UIPackConfig.Packs = {
	-- The base-UI default: a scrollable LIST of boxy nested-box rows (see
	-- UIListRowComponent / Reference RefServersShop). CardHeight is the row
	-- height in px (load-bearing in List mode); EntryLayout "ServerRow" is what
	-- routes ShopScreen to the UIListRowComponent renderer.
	{
		Id = "Default",
		DisplayName = "Default",
		Shop = { Container = "List", Columns = 1, CardHeight = 200, EntryLayout = "ServerRow", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1, MoneyRegion = "TopRight", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.42 },
	},

	-- Standard 2.0: like Standard, but the price rides on the RIGHT of the tag
	-- row (name above, buy below); badges shrink so they never reach the price.
	{
		Id = "StandardPlus",
		DisplayName = "Standard 2.0",
		Shop = { Container = "Grid", Columns = 4, CardHeight = 288, EntryLayout = "StandardCardPlus", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1, MoneyRegion = "TopRight", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.42 },
	},

	-- Standard, but the tag badges (Sale/New/Popular/…) straddle the image's TOP
	-- edge — half overlapping onto the art, half hanging above it — instead of
	-- sitting in the text column below. A poster/movie-banner feel.
	{
		Id = "StandardBanner",
		DisplayName = "Standard (Banner on Image)",
		Shop = { Container = "Grid", Columns = 4, CardHeight = 288, EntryLayout = "StandardCardBanner", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1, MoneyRegion = "TopRight", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.42 },
	},

	-- Image is the hero: fewer, larger cards, centred text. Premium storefront.
	{
		Id = "ImageShowcase",
		DisplayName = "Image Showcase",
		Shop = { Container = "Grid", Columns = 4, CardHeight = 338, EntryLayout = "ImageFocal", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1.05, MoneyRegion = "TopRight", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.5 },
	},

	-- Dense horizontal rows. Text/list-friendly; fixes the old broken "Compact".
	{
		Id = "Compact",
		DisplayName = "Compact / List",
		Shop = { Container = "List", Columns = 1, CardHeight = 76, EntryLayout = "ListRow", ShowCategoryBar = true },
		HUD = { Compact = true, ShowObjectives = false, Scale = 0.9, MoneyRegion = "TopRight", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Top" },
		Tutorial = { ShowStepList = false },
		Modal = { WidthScale = 0.36 },
	},

	-- Description-forward rows. For text-heavy menus, settings, info-rich shops.
	{
		Id = "Detailed",
		DisplayName = "Detailed / Text",
		Shop = { Container = "List", Columns = 1, CardHeight = 158, EntryLayout = "TextHeavy", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1, MoneyRegion = "TopLeft", MoneyIconSide = "Right" },
		Nav = { Side = "Right", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.46 },
	},

	-- Image left, details right. A middle-ground catalogue feel.
	{
		Id = "Split",
		DisplayName = "Split View",
		Shop = { Container = "Grid", Columns = 3, CardHeight = 206, EntryLayout = "SplitLeft", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1, MoneyRegion = "TopCenter", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.44 },
	},

	-- Full-width hero banners: big image, headline + description, prominent buy.
	{
		Id = "Hero",
		DisplayName = "Hero Banner",
		Shop = { Container = "List", Columns = 1, CardHeight = 200, EntryLayout = "HeroBanner", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1.05, MoneyRegion = "TopRight", MoneyIconSide = "Right" },
		Nav = { Side = "Right", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.5 },
	},

	-- ---- New layout packs -------------------------------------------------

	-- Tight grid of small square icon tiles. Wall-of-items storefront.
	{
		Id = "IconGrid",
		DisplayName = "Icon Grid",
		-- Was 6, then 5 as the panel narrowed; settled on 4 to match the rest of
		-- the packs and keep tiles comfortably sized, not cramped.
		Shop = { Container = "Grid", Columns = 4, CardHeight = 236, EntryLayout = "IconTile", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1, MoneyRegion = "TopRight", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Top" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.42 },
	},

	-- Three square showcase cards per row so the square art fills the card width
	-- (a 2-wide card leaves big side gaps around a square image). Premium look.
	{
		Id = "SquareShowcase",
		DisplayName = "Square Showcase",
		Shop = { Container = "Grid", Columns = 4, CardHeight = 316, EntryLayout = "SquareShowcase", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1.05, MoneyRegion = "TopCenter", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.5 },
	},

	-- Roomy detail rows with a larger square thumbnail. Inventory / quest log.
	{
		Id = "Inventory",
		DisplayName = "Inventory List",
		Shop = { Container = "List", Columns = 1, CardHeight = 92, EntryLayout = "DetailRow", ShowCategoryBar = true },
		HUD = { Compact = true, ShowObjectives = false, Scale = 0.95, MoneyRegion = "TopLeft", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Top" },
		Tutorial = { ShowStepList = false },
		Modal = { WidthScale = 0.4 },
	},

	-- Mirror split: text left, square image right. Spotlight catalogue.
	{
		Id = "Spotlight",
		DisplayName = "Spotlight (Mirror Split)",
		Shop = { Container = "Grid", Columns = 3, CardHeight = 214, EntryLayout = "SplitRight", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1, MoneyRegion = "TopRight", MoneyIconSide = "Right" },
		Nav = { Side = "Right", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.46 },
	},

	-- Tall portrait cards, three across. Character/skin/gacha select.
	{
		Id = "Roster",
		DisplayName = "Roster (Portrait)",
		Shop = { Container = "Grid", Columns = 4, CardHeight = 324, EntryLayout = "Portrait", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1, MoneyRegion = "TopRight", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.46 },
	},

	-- Compact settings/menu list: small icon, name, tiny action. Text-heavy menus.
	{
		Id = "Menu",
		DisplayName = "Menu / Settings",
		Shop = { Container = "List", Columns = 1, CardHeight = 68, EntryLayout = "MenuRow", ShowCategoryBar = false },
		HUD = { Compact = true, ShowObjectives = false, Scale = 0.9, MoneyRegion = "TopRight", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Top" },
		Tutorial = { ShowStepList = false },
		Modal = { WidthScale = 0.5 },
	},

	-- Taller-than-square art (not everything is a perfect square) — the image
	-- still fills the card width edge-to-edge, it's just less square about it.
	{
		Id = "TallShowcase",
		DisplayName = "Tall Showcase",
		Shop = { Container = "Grid", Columns = 4, CardHeight = 400, EntryLayout = "TallCard", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1, MoneyRegion = "TopRight", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.44 },
	},

	-- Square image in a tidy box with a separate, smaller PILL buy button
	-- floating below it (never flush against the image) — a different feel from
	-- the flush full-width Buy every other square pack uses.
	{
		Id = "StandardPro",
		DisplayName = "Standard Pro",
		Shop = { Container = "Grid", Columns = 4, CardHeight = 300, EntryLayout = "StandardPro", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1, MoneyRegion = "TopRight", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.44 },
	},

	-- Same premium image showcase, but no scrim/shadow — a small translucent
	-- flat panel sits behind just the text, keeping the rest of the art clean.
	{
		Id = "ImageShowcaseFlat",
		DisplayName = "Image Showcase (Flat)",
		Shop = { Container = "Grid", Columns = 4, CardHeight = 338, EntryLayout = "ImageFocalFlat", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1.05, MoneyRegion = "TopRight", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.5 },
	},

	-- Inventory view: rows show an OWNED-COUNT badge bottom-right instead of a
	-- Buy button — for browsing what you have, not what you can purchase.
	{
		Id = "MyItems",
		DisplayName = "My Items (Inventory)",
		Shop = { Container = "List", Columns = 1, CardHeight = 80, EntryLayout = "QuantityRow", ShowCategoryBar = true },
		HUD = { Compact = true, ShowObjectives = false, Scale = 0.95, MoneyRegion = "TopRight", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Top" },
		Tutorial = { ShowStepList = false },
		Modal = { WidthScale = 0.4 },
	},

	-- Inventory GRID: the card IS the square image, full-bleed, with just an
	-- owned-count badge in the bottom-right corner — nothing else in the way.
	{
		Id = "MyItemsGrid",
		DisplayName = "My Items (Grid)",
		Shop = { Container = "Grid", Columns = 4, CardHeight = 236, EntryLayout = "QuantityTile", ShowCategoryBar = true },
		HUD = { Compact = true, ShowObjectives = false, Scale = 0.95, MoneyRegion = "TopRight", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Top" },
		Tutorial = { ShowStepList = false },
		Modal = { WidthScale = 0.42 },
	},

	-- Square image in a clean box; the buy button floats fully OUTSIDE/below it
	-- — a bigger visual break than the Pill style (which still lives in the box).
	{
		Id = "OutsideBox",
		DisplayName = "Outside Box",
		Shop = { Container = "Grid", Columns = 4, CardHeight = 300, EntryLayout = "OutsideCard", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1, MoneyRegion = "TopRight", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.44 },
	},

	-- Square image in a clean box; the buy button straddles the box's bottom
	-- edge — half overlapping inside, half hanging out below it.
	{
		Id = "StraddleBox",
		DisplayName = "Straddle Box",
		Shop = { Container = "Grid", Columns = 4, CardHeight = 290, EntryLayout = "StraddleCard", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1, MoneyRegion = "TopRight", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.44 },
	},

	-- Minimalist "poster" look: the card IS the image, clean everywhere except
	-- one translucent strip crossing the vertical middle with just the name.
	-- Price/buy sit in a small translucent footer at the bottom.
	{
		Id = "CenterStrip",
		DisplayName = "Center Strip",
		Shop = { Container = "Grid", Columns = 4, CardHeight = 236, EntryLayout = "CenterStripCard", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1, MoneyRegion = "TopRight", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.42 },
	},
} :: { Types.UIPack }

function UIPackConfig.GetById(id: string): Types.UIPack?
	for _, pack in UIPackConfig.Packs do
		if pack.Id == id then
			return pack
		end
	end
	return nil
end

return UIPackConfig

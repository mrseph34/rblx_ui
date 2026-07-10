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

UIPackConfig.DefaultPackId = "Standard"

UIPackConfig.Packs = {
	-- Balanced grid of medium cards. The everyday default.
	{
		Id = "Standard",
		DisplayName = "Standard",
		Shop = { Container = "Grid", Columns = 3, CardHeight = 288, EntryLayout = "StandardCard", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1, MoneyRegion = "TopRight", MoneyIconSide = "Left" },
		Nav = { Side = "Left", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.42 },
	},

	-- Image is the hero: fewer, larger cards, centred text. Premium storefront.
	{
		Id = "ImageShowcase",
		DisplayName = "Image Showcase",
		Shop = { Container = "Grid", Columns = 2, CardHeight = 338, EntryLayout = "ImageFocal", ShowCategoryBar = true },
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
		Shop = { Container = "List", Columns = 1, CardHeight = 200, EntryLayout = "TextHeavy", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1, MoneyRegion = "TopLeft", MoneyIconSide = "Right" },
		Nav = { Side = "Right", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.46 },
	},

	-- Image left, details right. A middle-ground catalogue feel.
	{
		Id = "Split",
		DisplayName = "Split View",
		Shop = { Container = "Grid", Columns = 2, CardHeight = 206, EntryLayout = "SplitLeft", ShowCategoryBar = true },
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
		Shop = { Container = "Grid", Columns = 3, CardHeight = 316, EntryLayout = "SquareShowcase", ShowCategoryBar = true },
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
		Shop = { Container = "Grid", Columns = 2, CardHeight = 214, EntryLayout = "SplitRight", ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1, MoneyRegion = "TopRight", MoneyIconSide = "Right" },
		Nav = { Side = "Right", Vertical = "Center" },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.46 },
	},

	-- Tall portrait cards, three across. Character/skin/gacha select.
	{
		Id = "Roster",
		DisplayName = "Roster (Portrait)",
		Shop = { Container = "Grid", Columns = 3, CardHeight = 324, EntryLayout = "Portrait", ShowCategoryBar = true },
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

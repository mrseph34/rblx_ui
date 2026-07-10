--!strict
-- Entry layout specs — the heart of layout-pack variety.
--
-- An "entry" is a repeated data row/card (a shop item today; inventory slots,
-- quest rows, leaderboard rows tomorrow). Every entry is built by ONE renderer
-- (UICardComponent) from a spec chosen here. That is the consistency guarantee:
-- variety comes from swapping specs, never from bespoke per-pack card code, so
-- two items in the same pack are always structurally identical and a theme
-- always paints them the same way.
--
-- A spec picks an `arrangement` (how the renderer positions image/name/price/
-- buy/tags/description) and tunes it with parameters. Add a new look by adding
-- a spec here and pointing a pack at it — no renderer or screen changes.

local EntryLayoutConfig = {}

-- arrangement:
--   "CardTop"   image on top, text stacked below (grid card; standard/image-focal)
--   "Row"       small image left · name+tags middle · price+buy right (list/compact)
--   "Split"     large image left · name+desc+price+buy right (split feel)
--   "TextFirst" name+description hero, small image top-right, price+buy footer (text-heavy)
--   "Banner"    wide hero: big image left half, text+buy right half (featured)
export type EntrySpec = {
	arrangement: "CardTop" | "Row" | "Split" | "TextFirst" | "Banner",
	-- Focal sizing. Interpreted per arrangement (see renderer):
	--   CardTop  -> imageHeight (px)
	--   Row      -> imageSize (px, square)
	--   Split    -> imageWidth (0..1 fraction of the card)
	--   TextFirst-> imageSize (px, square)
	--   Banner   -> imageWidth (0..1 fraction)
	imageHeight: number?,
	imageSize: number?,
	imageWidth: number?,
	-- Locks the focal image to width:height = imageAspect (1 = square). Games use
	-- mostly square art, so most specs set ~1. 0/nil = fill the reserved size
	-- (used by wide banners that intentionally want a cinematic rectangle).
	imageAspect: number?,
	showTags: boolean,
	showDescription: boolean,
	-- "Full" wide button, "Compact" small right-aligned, "IconRight" tiny.
	buyStyle: "Full" | "Compact" | "IconRight",
	nameAlign: Enum.TextXAlignment,
	-- Split only: put the image on the RIGHT and the text column on the left.
	mirror: boolean?,
}

EntryLayoutConfig.Specs = {
	StandardCard = {
		arrangement = "CardTop",
		imageHeight = 118,
		imageAspect = 1, -- square art, the realistic default
		showTags = true,
		showDescription = false,
		buyStyle = "Full",
		nameAlign = Enum.TextXAlignment.Left,
	},
	ImageFocal = {
		arrangement = "CardTop",
		imageHeight = 150,
		imageAspect = 1,
		showTags = true,
		showDescription = false,
		buyStyle = "Full",
		nameAlign = Enum.TextXAlignment.Center,
	},
	ListRow = {
		arrangement = "Row",
		imageSize = 52,
		imageAspect = 1,
		showTags = true,
		showDescription = false,
		buyStyle = "Compact",
		nameAlign = Enum.TextXAlignment.Left,
	},
	TextHeavy = {
		arrangement = "TextFirst",
		imageSize = 48,
		imageAspect = 1,
		showTags = true,
		showDescription = true,
		buyStyle = "Full",
		nameAlign = Enum.TextXAlignment.Left,
	},
	SplitLeft = {
		arrangement = "Split",
		imageWidth = 0.42,
		imageAspect = 1, -- square image column, not a tall strip
		showTags = true,
		showDescription = true,
		buyStyle = "Full",
		nameAlign = Enum.TextXAlignment.Left,
	},
	HeroBanner = {
		arrangement = "Banner",
		imageWidth = 0.42,
		imageAspect = 0, -- cinematic wide image on purpose
		showTags = true,
		showDescription = true,
		buyStyle = "Full",
		nameAlign = Enum.TextXAlignment.Left,
	},

	-- ---- New layout specs -------------------------------------------------

	-- Small square tiles, centred, minimal text — an icon grid / storefront wall.
	IconTile = {
		arrangement = "CardTop",
		imageHeight = 96,
		imageAspect = 1,
		showTags = false,
		showDescription = false,
		buyStyle = "Compact",
		nameAlign = Enum.TextXAlignment.Center,
	},
	-- Big square hero card: large square image, centred name/price, full buy.
	SquareShowcase = {
		arrangement = "CardTop",
		imageHeight = 172,
		imageAspect = 1,
		showTags = true,
		showDescription = false,
		buyStyle = "Full",
		nameAlign = Enum.TextXAlignment.Center,
	},
	-- Dense list row with description — inventory / quest-log feel.
	DetailRow = {
		arrangement = "Row",
		imageSize = 64,
		imageAspect = 1,
		showTags = true,
		showDescription = false,
		buyStyle = "Compact",
		nameAlign = Enum.TextXAlignment.Left,
	},
	-- Image RIGHT, text left (mirror of Split) — magazine/spotlight feel.
	SplitRight = {
		arrangement = "Split",
		imageWidth = 0.42,
		imageAspect = 1,
		showTags = true,
		showDescription = true,
		buyStyle = "Full",
		nameAlign = Enum.TextXAlignment.Left,
		mirror = true,
	},
	-- Tall portrait card: 3:4 image, gacha/character-select feel.
	Portrait = {
		arrangement = "CardTop",
		imageHeight = 176,
		imageAspect = 0.75, -- 3:4 portrait
		showTags = true,
		showDescription = false,
		buyStyle = "Full",
		nameAlign = Enum.TextXAlignment.Center,
	},
	-- Compact icon+name chip row, buy as a tiny icon — settings/menu list feel.
	MenuRow = {
		arrangement = "Row",
		imageSize = 40,
		imageAspect = 1,
		showTags = false,
		showDescription = false,
		buyStyle = "IconRight",
		nameAlign = Enum.TextXAlignment.Left,
	},
} :: { [string]: EntrySpec }

function EntryLayoutConfig.Get(id: string): EntrySpec
	return EntryLayoutConfig.Specs[id] or EntryLayoutConfig.Specs.StandardCard
end

return EntryLayoutConfig

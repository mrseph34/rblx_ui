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
	showTags: boolean,
	showDescription: boolean,
	-- "Full" wide button, "Compact" small right-aligned, "IconRight" tiny.
	buyStyle: "Full" | "Compact" | "IconRight",
	nameAlign: Enum.TextXAlignment,
}

EntryLayoutConfig.Specs = {
	StandardCard = {
		arrangement = "CardTop",
		imageHeight = 78,
		showTags = true,
		showDescription = false,
		buyStyle = "Full",
		nameAlign = Enum.TextXAlignment.Left,
	},
	ImageFocal = {
		arrangement = "CardTop",
		imageHeight = 130,
		showTags = true,
		showDescription = false,
		buyStyle = "Full",
		nameAlign = Enum.TextXAlignment.Center,
	},
	ListRow = {
		arrangement = "Row",
		imageSize = 52,
		showTags = true,
		showDescription = false,
		buyStyle = "Compact",
		nameAlign = Enum.TextXAlignment.Left,
	},
	TextHeavy = {
		arrangement = "TextFirst",
		imageSize = 44,
		showTags = true,
		showDescription = true,
		buyStyle = "Full",
		nameAlign = Enum.TextXAlignment.Left,
	},
	SplitLeft = {
		arrangement = "Split",
		imageWidth = 0.38,
		showTags = true,
		showDescription = true,
		buyStyle = "Full",
		nameAlign = Enum.TextXAlignment.Left,
	},
	HeroBanner = {
		arrangement = "Banner",
		imageWidth = 0.42,
		showTags = true,
		showDescription = true,
		buyStyle = "Full",
		nameAlign = Enum.TextXAlignment.Left,
	},
} :: { [string]: EntrySpec }

function EntryLayoutConfig.Get(id: string): EntrySpec
	return EntryLayoutConfig.Specs[id] or EntryLayoutConfig.Specs.StandardCard
end

return EntryLayoutConfig

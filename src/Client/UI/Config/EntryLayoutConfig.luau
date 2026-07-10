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
--   "Overlay"   full-bleed image with text overlaid on a bottom scrim (image showcase)
export type EntrySpec = {
	arrangement: "CardTop" | "Row" | "Split" | "TextFirst" | "Banner" | "Overlay",
	-- Focal sizing. Interpreted per arrangement (see renderer):
	--   CardTop  -> imageHeight (px)
	--   Row      -> imageSize (px, square)
	--   Split    -> imageWidth (0..1 fraction of the card)
	--   TextFirst-> imageSize (px, square)
	--   Banner   -> imageWidth (0..1 fraction)
	imageHeight: number?,
	imageSize: number?,
	imageWidth: number?,
	-- Focal image shape, as width:height. For CardTop the image is ALWAYS a fixed
	-- imageHeight tall, width = imageHeight * imageAspect, CENTRED in its row —
	-- 1 (or nil/0) = square, the AAA default; 0.75 = portrait; >1 = wide. Change
	-- this per spec to reshape the art slot without touching the renderer.
	imageAspect: number?,
	-- CardTop only. true = image fills the full card content width edge-to-edge
	-- (no side margin; the card is exactly as tall as it needs to be — can end up
	-- a bit long, and that's fine). false/nil = image is a centred square/rect
	-- capped to keep the whole card near a compact ~1:1.2 ratio (small even side
	-- margins). Two legitimate looks, picked per spec.
	imageFillWidth: boolean?,
	showTags: boolean,
	showDescription: boolean,
	-- "Full" wide button, "Compact" small right-aligned, "IconRight" tiny,
	-- "Pill" a smaller centred rounded button with extra breathing room BELOW the
	-- image box (still inside the same card surface), "Quantity" shows an
	-- owned-count badge INSTEAD of a buy button (inventory view — nothing to
	-- purchase, just what you have). CardTop only, and both escape the card's
	-- clipped surface entirely (built as a sibling, not clipped by it):
	-- "OutsideBelow" floats the button fully below the box, not touching it.
	-- "Straddle" centres the button ON the box's bottom edge — half overlapping
	-- inside, half hanging out below.
	buyStyle: "Full" | "Compact" | "IconRight" | "Pill" | "Quantity" | "OutsideBelow" | "Straddle",
	nameAlign: Enum.TextXAlignment,
	-- Split only: put the image on the RIGHT and the text column on the left.
	mirror: boolean?,
	-- Overlay only: "Scrim" (default) = dark gradient fading up from the bottom
	-- edge behind the text. "Flat" = no gradient/shadow at all — just a small
	-- rounded, semi-transparent flat-colour panel sitting directly behind the
	-- text block, so the rest of the image stays completely clean.
	overlayBg: ("Scrim" | "Flat")?,
}

EntryLayoutConfig.Specs = {
	StandardCard = {
		arrangement = "CardTop",
		imageAspect = 1, -- square art, the realistic default
		imageFillWidth = true, -- fills the card edge-to-edge, no side margin
		showTags = true,
		showDescription = false,
		buyStyle = "Full",
		nameAlign = Enum.TextXAlignment.Left,
	},
	-- Image showcase: full-bleed square art with name/price/tags/buy OVERLAID on a
	-- bottom scrim so the text reads over the image. The card IS the image (compact).
	ImageFocal = {
		arrangement = "Overlay",
		imageAspect = 1,
		overlayBg = "Scrim",
		showTags = true,
		showDescription = false,
		buyStyle = "Compact",
		nameAlign = Enum.TextXAlignment.Left,
	},
	-- Same showcase, but no scrim/shadow at all — a small translucent flat panel
	-- sits behind just the text so the rest of the art stays completely clean.
	ImageFocalFlat = {
		arrangement = "Overlay",
		imageAspect = 1,
		overlayBg = "Flat",
		showTags = true,
		showDescription = false,
		buyStyle = "Compact",
		nameAlign = Enum.TextXAlignment.Left,
	},
	-- Taller-than-square art (fills the card width, so a smaller aspect makes it
	-- noticeably longer) — the "not everything has to be a perfect square" pack.
	-- 0.8 reads as clearly non-square without turning into a lanky strip.
	TallCard = {
		arrangement = "CardTop",
		imageAspect = 0.8,
		imageFillWidth = true,
		showTags = true,
		showDescription = false,
		buyStyle = "Full",
		nameAlign = Enum.TextXAlignment.Left,
	},
	-- Square image in its own tidy box, then a smaller PILL buy button sitting
	-- below it with real breathing room — never flush against the image, and a
	-- distinctly different (smaller, rounder) shape than the full-width button.
	StandardPro = {
		arrangement = "CardTop",
		imageHeight = 150,
		imageAspect = 1,
		showTags = true,
		showDescription = false,
		buyStyle = "Pill",
		nameAlign = Enum.TextXAlignment.Center,
	},
	-- Inventory view: a row with a square thumbnail and an OWNED-COUNT badge in
	-- the bottom-right instead of a buy button — for showing what you have, not
	-- what you can purchase.
	QuantityRow = {
		arrangement = "Row",
		imageSize = 56,
		imageAspect = 1,
		showTags = false,
		showDescription = false,
		buyStyle = "Quantity",
		nameAlign = Enum.TextXAlignment.Left,
	},
	-- Inventory GRID view: the card IS the square image, full-bleed, with just an
	-- owned-count badge overlaid in the bottom-right corner (and tags top-left).
	-- No name/price clutter — for browsing a grid of what you own.
	QuantityTile = {
		arrangement = "Overlay",
		imageAspect = 1,
		showTags = true,
		showDescription = false,
		buyStyle = "Quantity",
		nameAlign = Enum.TextXAlignment.Left,
	},
	-- Square image in a clean box; the buy button floats FULLY OUTSIDE/below the
	-- box (not overlapping it at all) — a bigger visual break from the image than
	-- the Pill style, which still sits inside the same rounded surface.
	OutsideCard = {
		arrangement = "CardTop",
		imageHeight = 150,
		imageAspect = 1,
		showTags = true,
		showDescription = false,
		buyStyle = "OutsideBelow",
		nameAlign = Enum.TextXAlignment.Center,
	},
	-- Square image in a clean box; the buy button straddles the box's bottom
	-- edge — half overlapping inside the box, half hanging out below it.
	StraddleCard = {
		arrangement = "CardTop",
		imageHeight = 150,
		imageAspect = 1,
		showTags = true,
		showDescription = false,
		buyStyle = "Straddle",
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
		imageHeight = 120,
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

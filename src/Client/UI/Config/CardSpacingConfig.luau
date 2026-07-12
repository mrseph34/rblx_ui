--!strict
-- Every gap/height inside a shop card, as a SCALE FRACTION of the card's own
-- CONTENT area — i.e. of `col` (the padded column every element stacks in),
-- NOT of the outer card's full height. This distinction matters: `col` fills
-- exactly the space left over after SurfacePadding is subtracted from both
-- the top and bottom, so a value meant to occupy a fraction of THAT space
-- must be expressed relative to it, not to the outer card. Getting this
-- backwards (fractions summed to their pre-conversion pixel-formula ratios,
-- but applied directly against `col`) is what caused a real, confirmed bug:
-- content underfilled `col` by ~3%, leaving an asymmetric empty gap below the
-- buy button (top gap ~3px, bottom gap ~5.7px on a live measured card) even
-- though every element rendered at the right individual size.
--
-- Every Height.*/Gap.* value below is "this many multiples of col's own
-- height," and the whole set is derived to sum to EXACTLY 1.0 (image + every
-- gap + every row), so col's content always exactly fills col with no leftover
-- space at the bottom, at any card size.
--
-- CardTop.AspectRatio (width:height) is the card's own fixed shape, applied
-- via a UIAspectRatioConstraint on the card surface (see UICardComponent).
--
-- Names describe the GAP, not a generic index, so "make X touch Y" is a
-- single line: find CardSpacing.Gap.TagsToName, set it to 0.

local CardSpacing = {}

-- CardTop's width:height ratio for a SQUARE focal image (imageAspect = 1),
-- matching the pre-conversion StandardCard look exactly (computed from the
-- old pixel formula at a representative column width — see the commit that
-- introduced this file for the derivation).
CardSpacing.CardTop = {
	-- The image row's fraction of col's own height for the FULL layout
	-- (tags + name + price + BuyFull-style buy) — kept as a named constant
	-- for readability/backwards-compat at call sites that only care about
	-- the default square-image full-layout shape. Every OTHER shape (skipped
	-- Tags/Price rows, Pill buyStyle, external buy) gets ITS OWN fraction via
	-- ImageFracFor below — see that function's comment for why one shared
	-- constant doesn't work for every spec.
	ImageFracOfCol = 0.661402,
}
-- AspectRatio (card width:height at imageAspect=1) is just ImageFracOfCol at
-- aspect=1 — kept as its own field for readability at call sites that only
-- care about the default square-image shape.
CardSpacing.CardTop.AspectRatio = CardSpacing.CardTop.ImageFracOfCol

-- Computes the CORRECT card width:height ratio for a given spec's imageAspect
-- (image width:height), so the focal image always renders at its actual
-- declared aspect ratio instead of being stretched/cropped to fit a
-- one-size-fits-all card shape. Derivation: card width is fixed by the grid; contentW (image
-- width, imageFillWidth) = (1-2*SurfacePadding) * cardW; imgH = contentW /
-- imageAspect; colH = (1-2*SurfacePadding) * cardH; imgH also = ImageFracOfCol
-- * colH (the fixed fraction every OTHER config value is tuned around).
-- Setting these equal and simplifying (the (1-2*SurfacePadding) terms cancel):
--   cardW / cardH = ImageFracOfCol * imageAspect
-- A real, confirmed bug (TallCard/imageAspect=0.8 overflowing into the next
-- grid row) is what surfaced the need for this — every CardTop card was
-- using the SAME fixed AspectRatio regardless of its own image's real shape.
function CardSpacing.CardTop.AspectRatioFor(imageAspect: number?): number
	local aspect = imageAspect
	if not aspect or aspect <= 0 then
		aspect = 1
	end
	return CardSpacing.CardTop.ImageFracOfCol * aspect
end

-- The shop grid's UIGridLayout CellSize/CellPadding, pure Scale (fraction of
-- the scroll frame), hand-tuned live in Studio rather than derived from
-- column count + a pixel gap. Editing these directly controls how many
-- columns actually fit and how tightly cards pack — CellSizeX * columns +
-- CellPaddingX * (columns - 1) roughly fills the row width.
CardSpacing.GridCell = {
	CellSizeX = 0.231,
	CellSizeY = 0.65,
	CellPaddingX = 0.02,
	-- Locked exact value for ONLY the Standard pack's own spec (StandardCard)
	-- — ShopScreen reads this directly there, no computation, by explicit
	-- request. Every other CardTop/Overlay spec computes its own value
	-- instead (see ShopScreen:_RebuildLayout): reusing this flat number on a
	-- spec with a taller/shorter card left a real visible gap between rows,
	-- confirmed on every non-Standard grid pack.
	CellPaddingY = -0.06,
}

-- Overlay arrangement (the card IS the image, no text column below it) is
-- much SHORTER than a CardTop card at the same width — CardTop's card aspect
-- (width:height) is ~0.66 (image + text column), Overlay's is just the
-- image's own aspect (~1 for a square). Reusing CardTop's CellSizeY left a
-- huge unfilled gap below every Overlay row (confirmed via measurement: a
-- ~71px gap between rows on a live card). A separate, smaller flat value —
-- hand-tuned the same way as GridCell above — instead of one CellSizeY
-- shared by both arrangements.
CardSpacing.GridCellOverlay = {
	CellSizeY = 0.43,
	CellPaddingY = -0.04,
}

-- Surface (the card's visible box) inner padding, as a fraction of the card's
-- OWN full height (this one IS relative to the outer card, not col — it's
-- what carves col's content area out of the card in the first place).
CardSpacing.SurfacePadding = 0.03137254901960784

-- Element heights, as fractions of col's own height (see the module doc above
-- for why this is col, not the outer card).
CardSpacing.Height = {
	TagRow = 0.06276150627615062,
	-- Slightly taller than Price/TagRow: item names are unpredictable-length
	-- strings (unlike Price's always-short numeric text), so this needs more
	-- headroom to render at a legible size on small cards instead of
	-- TextScaled shrinking below its own MinTextSize floor to force a fit —
	-- confirmed via direct measurement: at the old 0.06695 value, a real
	-- card's Name box rendered TextSize=8 despite MinTextSize=9.
	Name = 0.075,
	Price = 0.06694560669456066,
	BuyFull = 0.1087866108786611,
	BuyCompact = 0.1087866108786611,
	BuyPill = 0.1004184100418410, -- 24/239
	BuyIconRight = 0.1087866108786611,
	TagPriceRow = 0.0753138075313807, -- 18/239
}

-- Gaps BETWEEN specific pairs of elements in the CardTop text column, in
-- LAYOUT ORDER, as fractions of col's own height. Each is independently
-- tunable — set any one to 0 to make that specific pair touch.
CardSpacing.Gap = {
	ImageToTags = 0.008368200836820083,
	TagsToName = 0,
	ImageToName = 0.008368200836820083, -- image bottom -> item name, when no tags
	NameToPrice = 0.008368200836820083,
	PriceToBuy = 0.008368200836820083,
	BuyToPill = 0.03347280334728033, -- price -> buy button, Pill style only (8/239)
	-- Buy sits flush against the card's own clipped bottom edge — no trailing
	-- gap. ImageFracOfCol above was already derived EXCLUDING this value (see
	-- its own comment), so zeroing it makes col's content sum to exactly 1.0
	-- with zero leftover space below the button, instead of reserving a
	-- deliberate gap there.
	BuyToBottom = 0,
}

-- Computes ImageFracOfCol for ANY CardTop text-column shape — not every spec
-- renders the same rows: tagStraddle, showTags=false, and
-- overlayBadgeAndPrice all skip the Tags row; overlayBadgeAndPrice ALSO
-- skips the Price row; buyStyle="Pill" uses a different gap+height
-- (BuyToPill+BuyPill) than every other buyStyle (PriceToBuy+BuyFull); and
-- buyStyle OutsideBelow/Straddle don't render Buy in col AT ALL (it's built
-- as a Root-level sibling instead — see UICardComponent._BuildExternalBuy).
-- Reusing ONE constant (ImageFracOfCol, tuned only for the full
-- tags+price+BuyFull layout) for every spec forced every OTHER shape into a
-- taller-or-shorter card than its actual content — leaving real dead space,
-- needing fake padding gaps to avoid it, or slightly overflowing col's own
-- bounds (all three confirmed, real bugs across different specs:
-- StandardBanner/tagStraddle, StandardPlus/overlayBadgeAndPrice, IconGrid/
-- showTags=false, StandardPro/Pill). This is the single source of truth:
-- 1.0 minus ONLY the rows/gaps THIS spec's card actually renders in col, so
-- every card shape is always exact — image, then whichever rows are
-- present, each separated by just their normal small gap, no padding ever
-- needed and nothing ever clipped.
function CardSpacing.CardTop.ImageFracFor(spec: {
	showTags: boolean?,
	tagStraddle: boolean?,
	overlayBadgeAndPrice: boolean?,
	buyStyle: string?,
}): number
	local G, H = CardSpacing.Gap, CardSpacing.Height
	local other = 0
	local includeTags = spec.showTags and not spec.tagStraddle and not spec.overlayBadgeAndPrice
	if includeTags then
		other += G.ImageToTags + H.TagRow + G.TagsToName
	else
		other += G.ImageToName
	end
	other += H.Name
	local includePrice = not spec.overlayBadgeAndPrice
	if includePrice then
		other += G.NameToPrice + H.Price
	end
	if spec.buyStyle == "OutsideBelow" or spec.buyStyle == "Straddle" then
		-- Buy is NOT in col at all for external styles — nothing more to add
		-- (see UICardComponent._BuildExternalBuy for where it actually goes).
	elseif spec.buyStyle == "Pill" then
		other += G.BuyToPill + H.BuyPill
	else
		other += G.PriceToBuy + H.BuyFull
	end
	return 1 - other
end

function CardSpacing.CardTop.AspectRatioForSpec(spec: { imageAspect: number? } & { [string]: any }): number
	local aspect = spec.imageAspect
	if not aspect or aspect <= 0 then
		aspect = 1
	end
	return CardSpacing.CardTop.ImageFracFor(spec) * aspect
end

-- Straddle-banner mode (tagStraddle spec flag): how far the tag row overlaps
-- UP over the image's top edge, as a fraction of col's own height.
CardSpacing.BannerStraddleOffset = -0.03347280334728033

-- External buy button (OutsideBelow/Straddle buyStyle), as fractions of col's
-- own height. BottomPad is 0 (flush, matching Gap.BuyToBottom's fix above) —
-- BelowGap/StraddleBelowGap stay nonzero since they're the deliberate visual
-- separation that defines the OutsideBelow/Straddle LOOK itself (the button
-- floating off the box), not leftover unaccounted space.
CardSpacing.ExternalBuy = {
	Height = 0.1087866108786611,
	BottomPad = 0,
	-- OutsideBelow: gap between the surface's own bottom edge and the top of
	-- the floating button below it.
	BelowGap = 0.03,
	-- Straddle: the button is centred ON the surface's bottom edge (half
	-- overlapping inside, half hanging out below) — this reserves a SMALL
	-- extra gap below the button's own bottom edge so it doesn't sit flush
	-- against the next row's card underneath it.
	StraddleBelowGap = 0.025,
}

return CardSpacing

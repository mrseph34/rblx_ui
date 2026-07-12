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
	-- The image row's fraction of col's own height at imageAspect=1 — i.e.
	-- 1.0 minus every OTHER row/gap in the Height/Gap tables below plus
	-- BuyToBottom, so the whole column sums to EXACTLY 1.0 (recompute this
	-- whenever any Height.*/Gap.* value changes, or col's content will
	-- over/underfill col again — see the module doc's warning about that
	-- exact bug class). Used by AspectRatioFor to compute the right card
	-- shape for any imageAspect (see that function's derivation below).
	ImageFracOfCol = 0.631402,
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
	CellSizeX = 0.23,
	CellSizeY = 0.65,
	CellPaddingX = 0.015,
	CellPaddingY = -0.05,
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
	-- Below the buy button, before the card's own clipped bottom edge — a
	-- deliberately bigger gap than the other (very tight) inter-element gaps
	-- above, so the button visibly doesn't sit flush against the card edge.
	BuyToBottom = 0.03,
}

-- Straddle-banner mode (tagStraddle spec flag): how far the tag row overlaps
-- UP over the image's top edge, as a fraction of col's own height.
CardSpacing.BannerStraddleOffset = -0.03347280334728033

-- External buy button (OutsideBelow/Straddle buyStyle), as fractions of col's
-- own height.
CardSpacing.ExternalBuy = {
	Height = 0.1087866108786611,
	BottomPad = 0.016736401673640166,
	BelowGap = 0.016736401673640166,
}

return CardSpacing

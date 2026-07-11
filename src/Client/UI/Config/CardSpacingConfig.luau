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

-- CardTop's fixed width:height ratio (matches the pre-conversion StandardCard
-- look exactly, computed from the old pixel formula at a representative
-- column width — see the commit that introduced this file for the derivation).
CardSpacing.CardTop = {
	AspectRatio = 0.7058823529411765,
}

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
	Name = 0.06694560669456066,
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

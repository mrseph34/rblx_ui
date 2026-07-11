--!strict
-- Every gap/height inside a shop card, as a SCALE FRACTION of the card's own
-- height (never a pixel Offset) — the same pattern proven in the reference
-- MainGui/Shop: an element's Size is always a fraction of its parent's real
-- AbsoluteSize, so Roblox's own layout engine resolves the correct pixel size
-- at ANY viewport with zero runtime scale math, zero UIScale, and text that
-- shrinks/grows via TextScaled in lockstep automatically.
--
-- CardTop.AspectRatio (width:height) is the card's own fixed shape, applied
-- via a UIAspectRatioConstraint on the card surface (see UICardComponent).
-- Every Height.*/Gap.* value below is "this many multiples of the card's own
-- height" — so changing AspectRatio alone re-proportions everything at once,
-- and tuning one gap never drifts out of sync with anything else (there is
-- only one source of truth; ShopScreen no longer duplicates this math).
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

-- Surface (the card's visible box) inner padding, as a fraction of the card's
-- own height, applied equally to all four sides via UIStyler.Padding-style use.
CardSpacing.SurfacePadding = 0.03137254901960784

-- Element heights, as fractions of the card's own height.
CardSpacing.Height = {
	TagRow = 0.058823529411764705,
	Name = 0.06274509803921569,
	Price = 0.06274509803921569,
	BuyFull = 0.10196078431372549,
	BuyCompact = 0.10196078431372549,
	BuyPill = 0.09411764705882353, -- 24/255
	BuyIconRight = 0.10196078431372549,
	TagPriceRow = 0.07058823529411765, -- 18/255
}

-- Gaps BETWEEN specific pairs of elements in the CardTop text column, in
-- LAYOUT ORDER, as fractions of the card's own height. Each is independently
-- tunable — set any one to 0 to make that specific pair touch.
CardSpacing.Gap = {
	ImageToTags = 0.00784313725490196,
	TagsToName = 0,
	ImageToName = 0.00784313725490196, -- image bottom -> item name, when no tags
	NameToPrice = 0.00784313725490196,
	PriceToBuy = 0.00784313725490196,
	BuyToPill = 0.03137254901960784, -- price -> buy button, Pill style only (8/255)
}

-- Straddle-banner mode (tagStraddle spec flag): how far the tag row overlaps
-- UP over the image's top edge, as a fraction of the card height.
CardSpacing.BannerStraddleOffset = -0.03137254901960784

-- External buy button (OutsideBelow/Straddle buyStyle), as fractions of the
-- card's own height.
CardSpacing.ExternalBuy = {
	Height = 0.10196078431372549,
	BottomPad = 0.01568627450980392,
	BelowGap = 0.01568627450980392,
}

return CardSpacing

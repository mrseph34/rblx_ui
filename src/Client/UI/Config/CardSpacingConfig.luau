--!strict
-- Every gap/height inside a shop card, named and in ONE place. This exists
-- because tuning card spacing used to mean hunting through UICardComponent's
-- renderer AND ShopScreen's height formula and changing matching magic numbers
-- in both — easy to get out of sync, slow to iterate. Now: change a number
-- here, both the renderer and ShopScreen's card-height math read it live.
--
-- Names describe the GAP, not a generic index, so "make X touch Y" is a single
-- line: find CardSpacing.Gap.TagsToName, set it to 0.

local CardSpacing = {}

-- Surface (the card's visible box) inner padding, all four sides.
CardSpacing.SurfacePadding = 8

-- Element heights (fixed, tight fits — see UICardComponent._MakeName's note on
-- why these are fixed instead of AutomaticSize).
CardSpacing.Height = {
	TagRow = 15, -- matches UIBadgeComponent's own height exactly, no slack
	Name = 17, -- tight fit for the Body text size (~16px glyph)
	Price = 17,
	BuyFull = 26,
	BuyCompact = 26,
	BuyPill = 24,
	BuyIconRight = 26,
	TagPriceRow = 18,
}

-- Gaps BETWEEN specific pairs of elements in the CardTop text column, in
-- LAYOUT ORDER. Each is independently tunable — set any one to 0 to make that
-- specific pair touch, without affecting any other gap.
CardSpacing.Gap = {
	ImageToTags = 2, -- image bottom -> tag badges (kept small on purpose)
	TagsToName = 0, -- tag badges -> item name (flush — no gap wanted here)
	ImageToName = 2, -- image bottom -> item name, when there are no tags
	NameToPrice = 2, -- item name -> price
	PriceToBuy = 0, -- price -> buy button
	BuyToPill = 8, -- price -> buy button, ONLY for the Pill buy style (more
	-- breathing room so a Pill button reads as a separate element)
}

-- Straddle-banner mode (tagStraddle spec flag): how far the tag row overlaps
-- UP over the image's top edge. Half the badge height reads as "straddling".
CardSpacing.BannerStraddleOffset = -8

return CardSpacing

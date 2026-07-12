--!strict
-- Data-driven shop. Renders currency header, category bar and an item grid/list
-- from ShopConfig + the active pack's layout. Cards are UICardComponents; the
-- buy flow raises a confirm modal, then calls the injected purchase function.
--
-- Layout (grid vs list, columns, card height) comes entirely from the active
-- UIPack, so switching packs re-lays-out the same data with no code change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local SharedTypes = require(ReplicatedStorage.Shared.Types)

local UIStyler = require(script.Parent.Parent.UIStyler)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local EntryLayoutConfig = require(script.Parent.Parent.Config.EntryLayoutConfig)
local CardSpacing = require(script.Parent.Parent.Config.CardSpacingConfig)
local UIScreenBase = require(script.Parent.UIScreenBase)
local UIPanelComponent = require(script.Parent.Parent.Components.UIPanelComponent)
local UIButtonComponent = require(script.Parent.Parent.Components.UIButtonComponent)
local UICardComponent = require(script.Parent.Parent.Components.UICardComponent)

local ShopScreen = setmetatable({}, { __index = UIScreenBase })
ShopScreen.__index = ShopScreen

function ShopScreen.new()
	local self = UIScreenBase.new("ShopScreen", 5)
	self._categoryId = "featured"
	self._balances = table.clone(ShopConfig.StartingBalances)
	-- Cards keyed by item id so re-renders can UPDATE existing cards instead of
	-- destroying/rebuilding the whole grid every time a balance or category
	-- changes (a full reload on every value tick is the kind of thing that would
	-- visibly flicker in a live game).
	self._cardsById = {} :: { [string]: any }
	self._cardOrder = {} :: { string }
	self._categoryButtons = {}
	self._currencyLabels = {}
	-- Injected by ClientHandler: (item) -> Types.PurchaseResult
	self._purchaseFn = nil :: ((SharedTypes.ShopItem) -> SharedTypes.PurchaseResult)?
	return setmetatable(self, ShopScreen)
end

function ShopScreen:SetPurchaseHandler(fn: (SharedTypes.ShopItem) -> SharedTypes.PurchaseResult)
	self._purchaseFn = fn
end

function ShopScreen:_BuildContent()
	-- Dim backdrop.
	local backdrop = UIStyler.Frame("Backdrop")
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.Parent = self.Root
	self._backdrop = backdrop

	local panel = UIPanelComponent.new()
	self._panel = panel
	self:_SetAnimatedPanel(panel)
	panel:Create(self.Root, {
		titleKey = "shop.title",
		-- Slightly wider, slightly shorter than before (0.5 x 0.86) — reads less
		-- like a tall column and gives the grid a bit more horizontal breathing
		-- room per row.
		size = UDim2.fromScale(0.56, 0.8),
		onClose = function()
			self.ScreenController:HideScreen("shop")
		end,
	})

	-- Currency chips live in the HEADER now (next to the close button), not
	-- their own row in Body — a Scale-sized row anchored left of Close, filling
	-- the header height exactly so it scales with everything else in it.
	local currencyBar = UIStyler.Frame("Currencies")
	currencyBar.BackgroundTransparency = 1
	currencyBar.AnchorPoint = Vector2.new(1, 0.5)
	-- Pure Scale: sits left of the close button (which is pinned at 0.98) with
	-- a small Scale gap — never a pixel Offset.
	currencyBar.Position = UDim2.new(0.9, 0, 0.5, 0)
	currencyBar.Size = UDim2.new(0.45, 0, 0.72, 0)
	UIStyler.ListLayout({
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.06, 0),
	}).Parent = currencyBar
	currencyBar.ZIndex = 2
	currencyBar.Parent = panel.Header
	for _, currency in ShopConfig.GetOrderedCurrencies() do
		local chip = UIStyler.TextLabel(currency.id)
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.Size = UDim2.fromScale(0, 1)
		chip.TextXAlignment = Enum.TextXAlignment.Right
		chip.TextScaled = true
		chip.ZIndex = 2
		local constraint = UIStyler.TextSizeConstraint(18, 9)
		constraint.Parent = chip
		chip.Parent = currencyBar
		self._currencyLabels[currency.id] = chip
	end

	-- Category bar — a horizontal UIListLayout of Scale-sized, evenly-spaced
	-- tab buttons (same structural idea as the reference MainGui's Featured/
	-- Boosts/Cosmetics tabs: one list, no per-button fixed pixel width, so it
	-- always keeps consistent spacing/sizing at any panel size).
	local categoryBar = UIStyler.Frame("Categories")
	categoryBar.BackgroundTransparency = 1
	-- Inset 2% on each side (98% wide) so a hovered/scaled-up tab at either end
	-- never pops outside the panel's own edge.
	categoryBar.Size = UDim2.new(0.98, 0, 0.08, 0)
	categoryBar.Position = UDim2.new(0.01, 0, 0.02, 0)
	UIStyler.ListLayout({
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.015, 0),
	}).Parent = categoryBar
	categoryBar.Parent = panel.Body
	self._categoryBar = categoryBar
	local categories = ShopConfig.GetOrderedCategories()
	local categoryWFrac = #categories > 0 and ((1 - 0.015 * (#categories - 1)) / #categories) or 1
	for i, category in categories do
		local button = UIButtonComponent.new()
		button:Create(categoryBar, {
			textKey = category.nameKey,
			variant = category.id == self._categoryId and "Primary" or "Ghost",
			size = UDim2.new(categoryWFrac, 0, 1, 0),
			layoutOrder = i,
			onClick = function()
				self:_SelectCategory(category.id)
			end,
		})
		self._categoryButtons[category.id] = button
	end

	-- Scrolling item container — Scale-sized, filling the rest of Body below
	-- the category bar.
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Items"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, 0, 0.88, 0)
	scroll.Position = UDim2.new(0, 0, 0.12, 0)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ClipsDescendants = true
	scroll.Parent = panel.Body
	self._scroll = scroll

	-- Inner padding so the first row/column and the last row don't touch the
	-- scroll edges (where the hover "pop" would otherwise clip), so the last row
	-- is never cut, and so the automatic canvas height includes a bottom margin.
	-- A SCALE fraction of the scroll's own size, applied once; per-render we
	-- rebuild only the layout object, not this.
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(-0.018, 0)
	pad.PaddingBottom = UDim.new(0, 0)
	pad.PaddingLeft = UDim.new(0.015, 0)
	pad.PaddingRight = UDim.new(0.011, 0)
	pad.Parent = scroll
	self._scrollPad = pad

	-- Re-render when the scroll frame's width first becomes known / changes, so the
	-- CardTop grid height (which is derived from the real cell width) is correct.
	-- Guarded by _lastScrollW so a no-op resize doesn't loop.
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local w = scroll.AbsoluteSize.X
		if w > 0 and math.abs(w - (self._lastScrollW or 0)) > 1 then
			self._lastScrollW = w
			self:_RebuildLayout()
		end
	end)

	self:_RebuildLayout()
end

function ShopScreen:_SelectCategory(categoryId: string)
	if categoryId == self._categoryId then
		return
	end
	self._categoryId = categoryId
	for id, button in self._categoryButtons do
		button.Props.variant = id == categoryId and "Primary" or "Ghost"
		button:ApplyTheme(self:GetTheme())
	end
	-- The category swaps which items show, so the grid/list geometry (a shape
	-- change) is recomputed; _RebuildLayout diffs cards, it does not destroy them.
	self:_RebuildLayout()
end

-- Compute the grid/list geometry for the active pack + spec (column layout,
-- per-arrangement card height, image pixel size), THEN sync cards into it. Call
-- this when the SHAPE changes (pack swap, category swap, scroll width first
-- known) — never on a plain data update like a balance tick.
function ShopScreen:_RebuildLayout()
	-- Clear any previous layout object (UIGridLayout/UIListLayout), but leave
	-- existing card Instances alone — _SyncItems reuses or destroys them by id.
	for _, child in self._scroll:GetChildren() do
		if child:IsA("UIGridLayout") or child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local pack = self.ThemeController:GetPack()
	local shopLayout = pack.Shop
	local spec = EntryLayoutConfig.Get(shopLayout.EntryLayout)
	self._activeSpec = spec
	self._activeShopLayout = shopLayout

	if shopLayout.Container == "Grid" and (spec.arrangement == "CardTop" or spec.arrangement == "Overlay") then
		-- Pure-Scale path (matches the reference MainGui pattern): the card now
		-- keeps its OWN fixed width:height ratio via a UIAspectRatioConstraint on
		-- the card itself (see UICardComponent._Build), with AspectType
		-- FitWithinMaxSize — so the grid CELL just needs to be a big-enough Scale
		-- box, and the card centres itself inside it at the correct shape. No
		-- pixel measurement, no per-pass height computation, no ShopScreen/
		-- CardSpacingConfig cross-referencing needed for either arrangement.
		self._cardImageSizePx = nil
		-- Pure Scale cell size/padding — hand-tuned to look right in Studio
		-- (see CardSpacingConfig.GridCell for the editable values) instead of
		-- computed from column count + a pixel gap.
		--
		-- CellPaddingY was tuned NEGATIVE against the default (imageAspect=1)
		-- card, whose real fitted height (via FitWithinMaxSize + DominantAxis
		-- Width) ends up SHORTER than the cell — the negative padding pulls
		-- rows closer to use up that leftover slack. A spec with a TALLER card
		-- shape (imageAspect < 1, via AspectRatioFor) has LESS (or no) such
		-- slack, so the same fixed negative padding overlaps adjacent rows (a
		-- real, confirmed bug on TallCard). Computed here instead of a static
		-- config number: mirrors Roblox's own FitWithinMaxSize resolution
		-- (candidate height from full cell width, clamped to the cell height)
		-- to find the ACTUAL slack for this spec's card shape, then only pads
		-- by that much — always exactly enough to close the gap, never enough
		-- to overlap, for any imageAspect.
		local cellWAbs = CardSpacing.GridCell.CellSizeX * self._scroll.AbsoluteSize.X
		local cellHAbs = CardSpacing.GridCell.CellSizeY * self._scroll.AbsoluteSize.Y
		-- Overlay's card IS the image (no text-block adjustment needed), so its
		-- card aspect is simply the image's own aspect; CardTop derives its card
		-- shape from AspectRatioFor (see that function for the full reasoning).
		local actualCardAspect = spec.arrangement == "Overlay"
			and (spec.imageAspect and spec.imageAspect > 0 and spec.imageAspect or 1)
			or CardSpacing.CardTop.AspectRatioFor(spec.imageAspect)
		local candidateCardH = actualCardAspect > 0 and (cellWAbs / actualCardAspect) or cellHAbs
		local fittedCardH = math.min(candidateCardH, cellHAbs)
		local slackAbs = fittedCardH - cellHAbs -- <= 0 always; the safe padding
		local paddingYFrac = self._scroll.AbsoluteSize.Y > 0 and (slackAbs / self._scroll.AbsoluteSize.Y) or 0
		local cell = UIStyler.GridLayout(
			UDim2.fromScale(CardSpacing.GridCell.CellSizeX, CardSpacing.GridCell.CellSizeY),
			UDim2.fromScale(CardSpacing.GridCell.CellPaddingX, paddingYFrac)
		)
		cell.Parent = self._scroll
	elseif shopLayout.Container == "Grid" then
		local cols = shopLayout.Columns
		local cellPad = 10
		local cardHeight = shopLayout.CardHeight
		-- For legacy Overlay specs (image-on-top), the image FILLS the card width
		-- and holds its aspect, so the card must be exactly tall enough for that
		-- image + the text block — no fixed height, no empty side space. We compute
		-- the real pixel cell width to derive that height. Other grid arrangements
		-- (Split) keep their configured CardHeight.
		if spec.arrangement == "Overlay" then
			local scrollW = self._scroll.AbsoluteSize.X
			if scrollW <= 0 then
				scrollW = 700 -- pre-measure fallback; corrected on the next render
			end
			local cellW = (scrollW - cellPad * (cols - 1)) / cols
			local aspect = spec.imageAspect
			if not aspect or aspect <= 0 then
				aspect = 1
			end
			if spec.arrangement == "Overlay" then
				-- The image IS the whole card (text is overlaid), so the card is just
				-- the square — very compact, so many tiles fit on screen at once.
				self._cardImageSizePx = math.floor(cellW)
				cardHeight = math.floor(cellW / aspect)
			else
				-- CardTop: square (or spec aspect) image over a text strip below.
				-- Exact height of everything below the image — built from the SAME
				-- CardSpacingConfig values UICardComponent._BuildCardTop reads, term
				-- for term, so this can never silently drift out of sync with the
				-- renderer again (a real bug class hit repeatedly before this config
				-- existed). Each `+ CardSpacing.Gap.X` below is one explicit spacer
				-- frame the renderer inserts; tune spacing by editing the config, not
				-- by hunting for matching magic numbers in two files.
				local H, G = CardSpacing.Height, CardSpacing.Gap
				local surfacePad = CardSpacing.SurfacePadding * 2
				-- tagStraddle puts the badges ON the image (a sibling of it, not a row
				-- in the text column below) — so it never occupies text-column height,
				-- same as if showTags were false for THIS purpose.
				local tagsInColumn = spec.showTags and not spec.tagStraddle
				local external = spec.buyStyle == "OutsideBelow" or spec.buyStyle == "Straddle"
				local textBlock
				if external then
					-- The buy button lives OUTSIDE the surface entirely (see
					-- UICardComponent._BuildExternalBuy) — the internal column ends
					-- with a small 4px pad instead of a buy row, and the reserved
					-- space for the external button is added on top, outside the
					-- surface's own content height. Reserve is half the external buy
					-- height for Straddle, or buttonH+gap for OutsideBelow (both
					-- computed in UICardComponent._Build/_BuildExternalBuy).
					local EB = CardSpacing.ExternalBuy
					local tagsBlock = tagsInColumn and (G.ImageToTags + H.TagRow + G.TagsToName) or G.ImageToName
					local reserve = spec.buyStyle == "Straddle" and math.floor(EB.Height / 2) or (EB.Height + EB.BelowGap)
					textBlock = surfacePad + tagsBlock + H.Name + G.NameToPrice + H.Price + EB.BottomPad + reserve
				elseif spec.priceWithTags then
					-- Standard 2.0: image, name, [tags+price on one row], buy.
					-- No separate tags/price rows.
					local buyH = spec.buyStyle == "Pill" and H.BuyPill or H.BuyFull
					local buyGap = spec.buyStyle == "Pill" and G.BuyToPill or G.PriceToBuy
					textBlock = surfacePad + G.ImageToName + H.Name + G.NameToPrice + H.TagPriceRow + buyGap + buyH
				elseif spec.overlayBadgeAndPrice then
					-- Standard 2.0: badges + price both overlay the image itself, so
					-- the text column below is just Name + Buy — no tags/price rows.
					local buyH = spec.buyStyle == "Pill" and H.BuyPill or H.BuyFull
					local buyGap = spec.buyStyle == "Pill" and G.BuyToPill or G.PriceToBuy
					textBlock = surfacePad + G.ImageToName + H.Name + buyGap + buyH
				else
					local tagsBlock = tagsInColumn and (G.ImageToTags + H.TagRow + G.TagsToName) or G.ImageToName
					local buyH = spec.buyStyle == "Pill" and H.BuyPill or H.BuyFull
					local buyGap = spec.buyStyle == "Pill" and G.BuyToPill or G.PriceToBuy
					textBlock = surfacePad + tagsBlock + H.Name + G.NameToPrice + H.Price + buyGap + buyH
				end
				if spec.imageFillWidth then
					-- Image fills the card content width edge-to-edge (no side margin).
					-- The card is exactly as tall as image + text needs — no target-ratio
					-- clamp, so it can end up a bit long, and that's the intended look.
					local imgW = cellW - 20
					local imgH = imgW / aspect
					self._cardImageSizePx = math.floor(imgW)
					cardHeight = math.floor(imgH + textBlock)
				else
					-- Compact look: the card targets a pleasant ~1:1.2 ratio and the
					-- image gets the leftover height as a CENTRED square/rect. On wide
					-- cards the box is a touch narrower than the card (small even
					-- margins, never a lonely edge); it never produces a lanky 1:2 card.
					local targetCardH = cellW * 1.2
					local imgH = math.clamp(targetCardH - textBlock, cellW * 0.62, cellW - 12)
					self._cardImageSizePx = math.floor(imgH * aspect)
					cardHeight = math.floor(imgH + textBlock)
				end
			end
		elseif spec.arrangement == "Split" or spec.arrangement == "Banner" then
			-- Split/Banner: the image just fills whatever height it's given, but the
			-- TEXT column's own stacked content (name/tags/desc/price/buy) is what
			-- actually determines how tall the card needs to be. A mismatched fixed
			-- CardHeight here is exactly what left dead space below the Buy button
			-- while the image side filled edge-to-edge — computed to match the
			-- renderer exactly (_BuildSplit) so there's never a gap either way.
			self._cardImageSizePx = nil
			local rows = 2 -- name (wrap-capable) + buy always present
			local rowsH = 30 + 30
			if spec.showTags then
				rows += 1
				rowsH += 15
			end
			if spec.showDescription then
				rows += 1
				rowsH += 44
			end
			rows += 2 -- price + spacer, always present
			rowsH += 17 + 2
			local gaps = (rows - 1) * 6
			cardHeight = math.floor(20 + rowsH + gaps) -- 20 = surface top+bottom padding
		else
			self._cardImageSizePx = nil
		end
		local cell = UIStyler.GridLayout(
			UDim2.new(1 / cols, -cellPad, 0, cardHeight),
			UDim2.fromOffset(cellPad, cellPad)
		)
		cell.Parent = self._scroll
	else
		self._cardImageSizePx = nil
		UIStyler.ListLayout({ Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = self._scroll
	end

	-- The layout shape (spec/columns) determines each card's Create-time props
	-- (spec, size, imageSizePx), so a shape change destroys and rebuilds every
	-- card — but a plain data change (balances, category re-select with the same
	-- items) never reaches this function and just calls _SyncItems below.
	for _, card in self._cardsById do
		card:Destroy()
	end
	table.clear(self._cardsById)
	table.clear(self._cardOrder)

	self:_SyncItems()
end

-- Reconcile self._cardsById against the current category's items: create cards
-- for new ids, destroy cards for ids no longer present, and UPDATE existing
-- cards' affordability/owned in place. This is what lets a balance change or a
-- purchase refresh the shop WITHOUT tearing down and rebuilding every entry —
-- the full-reload-on-every-tick pattern is bad in any live game.
function ShopScreen:_SyncItems()
	local shopLayout = self._activeShopLayout
	local spec = self._activeSpec
	if not shopLayout or not spec then
		return
	end

	local items = ShopConfig.GetItemsForCategory(self._categoryId)
	local seen = {}

	for i, item in items do
		seen[item.id] = true
		local currency = ShopConfig.Currencies[item.currencyType]
		local affordable = ShopConfig.CanAfford(self._balances, item)
		local existing = self._cardsById[item.id]
		if existing then
			-- Same item, same layout shape: just patch the parts that can change.
			existing:Update({ affordable = affordable })
			existing.Root.LayoutOrder = i
		else
			local card = UICardComponent.new()
			-- List rows get an explicit full-width size; grid cells are sized by the
			-- grid layout, so leave size nil there.
			local size = shopLayout.Container == "List" and UDim2.new(1, 0, 0, shopLayout.CardHeight) or nil
			card:Create(self._scroll, {
				item = item,
				spec = spec,
				currencyIcon = currency and currency.icon or "",
				affordable = affordable,
				layoutOrder = i,
				size = size,
				-- Exact image pixel width so a CardTop image fills the card with no gap.
				imageSizePx = self._cardImageSizePx,
				onBuy = function(boughtItem)
					self:_PromptPurchase(boughtItem)
				end,
			})
			card:PlayAnimation("Appear")
			self._cardsById[item.id] = card
		end
	end

	-- Drop cards for items that vanished (category filter changed the set, or an
	-- item was removed from config at runtime).
	for id, card in self._cardsById do
		if not seen[id] then
			card:Destroy()
			self._cardsById[id] = nil
		end
	end

	self:_RefreshCurrencies()
end

-- Raise a confirm modal; on confirm, run the injected purchase and toast.
function ShopScreen:_PromptPurchase(item: SharedTypes.ShopItem)
	local currency = ShopConfig.Currencies[item.currencyType]
	local body = string.format(
		"%s — %s %s",
		TextConfig.Resolve(item.nameKey),
		ShopConfig.FormatPrice(item.price),
		currency and TextConfig.Resolve(currency.nameKey) or ""
	)
	self.ScreenController:ShowModal({
		kind = "Confirm",
		titleKey = "modal.confirm_purchase.title",
		body = body,
		confirmKey = "shop.buy",
		cancelKey = "modal.cancel",
		onConfirm = function()
			self:_DoPurchase(item)
		end,
	})
end

function ShopScreen:_DoPurchase(item: SharedTypes.ShopItem)
	if not self._purchaseFn then
		return
	end
	local result = self._purchaseFn(item)
	if result.balances then
		self._balances = result.balances
	end
	local hud = self.ScreenController:GetScreen("hud")
	if hud then
		hud:PushToast({
			textKey = result.success and "shop.purchase_success" or result.messageKey,
			variant = result.success and "Success" or "Error",
		})
		if result.balances then
			hud:Update({ values = result.balances })
		end
	end
	-- A purchase only changes affordability/owned, never the layout shape, so
	-- sync cards in place rather than rebuilding the whole grid.
	self:_SyncItems()
end

function ShopScreen:_RefreshCurrencies()
	local theme = self:GetTheme()
	for id, label in self._currencyLabels do
		local currency = ShopConfig.Currencies[id]
		label.Text = string.format("%s %s", currency.icon, ShopConfig.FormatPrice(self._balances[id] or 0))
		label.FontFace = theme.Fonts.Numeric
		label.TextSize = theme.TextSizes.Body
		label.TextColor3 = (theme.Colors :: any)[currency.colorToken] or theme.Colors.TextPrimary
	end
end

function ShopScreen:_OnShow(data: any?)
	if data and data.balances then
		self._balances = data.balances
	end
	if data and data.categoryId and data.categoryId ~= self._categoryId then
		self._categoryId = data.categoryId
		-- Category changed while hidden: the item set (shape) changed too.
		self:_RebuildLayout()
	else
		-- Re-opening the shop: the pack could have changed while it was hidden
		-- (e.g. the Theme Editor's pack picker), so re-derive the layout shape.
		-- Cheap and infrequent (screen open), unlike a per-tick balance update.
		self:_RebuildLayout()
	end
	-- Intro is driven centrally by UIScreenBase:Show (active animation pack).
end

function ShopScreen:Update(data: any)
	if data.balances then
		self._balances = data.balances
		-- Balances can arrive (currency pushes, boot snapshot) before the shop
		-- has ever been opened/built; just cache them until first show. Once
		-- built, this is a pure data change — sync cards in place, never rebuild.
		if self._built then
			self:_SyncItems()
		end
	end
end

return ShopScreen

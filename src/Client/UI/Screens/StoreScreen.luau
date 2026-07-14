--!strict
-- EXCLUSIVE STORE screen — a UIScreenBase subclass that reproduces
-- Reference/RefExclusiveStore.luau BAR-FOR-BAR through the RefSkin primitive
-- (same modal, same featured pack panel, same nested boxes, same gradients,
-- sizes, positions, text sizes and outline thicknesses), then swaps the
-- reference's placeholder TEXT for REAL ShopConfig items. Every card / pack box
-- is a clickable RefSkin box (button = true) wired to a purchase flow that
-- mirrors ShopScreen (SetPurchaseHandler -> _PromptPurchase -> confirm modal ->
-- _DoPurchase). This is a pixel copy of the reference, not a theme-token
-- approximation, so it deliberately does NOT respond to theme tokens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local SharedTypes = require(ReplicatedStorage.Shared.Types)

local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local RefSkin = require(script.Parent.Parent.Reference.RefSkin)
local UIScreenBase = require(script.Parent.UIScreenBase)

local C = RefSkin.C

-- Reference-exact secondary colours (RefExclusiveStore's item-card stops).
local CARD_TOP = Color3.fromRGB(86, 172, 250)
local CARD_BOTTOM = Color3.fromRGB(30, 96, 200)
local CARD_BORDER = Color3.fromRGB(28, 84, 168)
local CARD_GAP = Color3.fromRGB(198, 224, 250)
local FEATURED_GAP = Color3.fromRGB(206, 226, 248)
local GREEN_GAP = Color3.fromRGB(224, 244, 218)

-- Items ship no real iconId yet (ShopConfig.iconId == ""), so the reference art
-- is an emoji placeholder exactly like RefExclusiveStore's 🛰️ / 📡 / 👟. Cycled
-- by slot so a full featured set gets varied placeholders.
local ITEM_EMOJI = { "🛰️", "📡", "👟", "🎁", "💠", "🚀", "🔮", "⚡", "🧿", "🎽", "🪙", "💎" }

local StoreScreen = setmetatable({}, { __index = UIScreenBase })
StoreScreen.__index = StoreScreen

function StoreScreen.new()
	local self = UIScreenBase.new("StoreScreen", 5)
	-- Which category the exclusive store showcases (localized in _BuildContent).
	self._categoryId = "featured"
	self._balances = table.clone(ShopConfig.StartingBalances)
	-- Injected by ClientHandler: (item) -> Types.PurchaseResult (mirrors ShopScreen).
	self._purchaseFn = nil :: ((SharedTypes.ShopItem) -> SharedTypes.PurchaseResult)?
	return setmetatable(self, StoreScreen)
end

-- Mirrors ShopScreen:SetPurchaseHandler — the authoritative purchase function is
-- injected at boot; the store just calls it and renders the result.
function StoreScreen:SetPurchaseHandler(fn: (SharedTypes.ShopItem) -> SharedTypes.PurchaseResult)
	self._purchaseFn = fn
end

-- The currency's image icon (was the emoji glyph appended to the price string).
-- Coins -> coin, Gems -> purpleGem; defaults to coin for any other currency.
local function currencyIcon(item: SharedTypes.ShopItem): string
	return item.currencyType == "Gems" and RefSkin.Assets.purpleGem or RefSkin.Assets.cash
end

-- One reference itemCard, but the OUTER box is a TextButton (button = true) so
-- the whole card is the buy control. Placeholder TEXT -> the real item's
-- name / price / tag. Every size / position / textSize / outline is the exact
-- RefExclusiveStore.itemCard value.
function StoreScreen:_ItemCard(parent: Instance, x: number, item: SharedTypes.ShopItem, emoji: string)
	local outer, inner = RefSkin.box(parent, {
		button = true,
		size = UDim2.fromScale(0.208, 0.86), position = UDim2.fromScale(x, 0.5), anchor = Vector2.new(0, 0.5),
		gradTop = CARD_TOP, gradBottom = CARD_BOTTOM, border = CARD_BORDER, lightBg = CARD_GAP, gap = 4, zindex = 4,
	})
	-- Name flush at the TOP edge, big + strongly outlined.
	RefSkin.label(inner, TextConfig.Resolve(item.nameKey), {
		size = UDim2.fromScale(0.96, 0.22), position = UDim2.fromScale(0.5, 0.1), anchor = Vector2.new(0.5, 0.5),
		color = C.White, outline = 4, textSize = 36, zindex = 6,
	})
	-- Item art directly on the card (emoji placeholder for the missing iconId).
	RefSkin.label(inner, emoji, {
		size = UDim2.fromScale(0.76, 0.46), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5),
		outline = 0, textSize = 96, zindex = 6,
	})
	-- Price flush at the BOTTOM edge: number + currency icon (was a "<n> <glyph>"
	-- string; an image can't live inside text). A holder frame carries the row so
	-- the card inner's other content stays put.
	local priceHolder = Instance.new("Frame")
	priceHolder.BackgroundTransparency = 1
	priceHolder.BorderSizePixel = 0
	priceHolder.Size = UDim2.fromScale(0.96, 0.22)
	priceHolder.Position = UDim2.fromScale(0.5, 0.9)
	priceHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	priceHolder.ZIndex = 6
	priceHolder.Parent = inner
	RefSkin.priceRow(priceHolder, ShopConfig.FormatPrice(item.price), currencyIcon(item), {
		textSize = 36, outline = 4, zindex = 6,
	})
	-- The item's primary tag as a small gold badge overlaying the top-right corner
	-- (exclusive-store "SALE / NEW" ribbon); hidden when the item has no tags.
	local tag = item.tags and item.tags[1] or nil
	if tag then
		RefSkin.label(inner, string.upper(tag), {
			size = UDim2.fromScale(0.5, 0.12), position = UDim2.fromScale(0.97, 0.28), anchor = Vector2.new(1, 0.5),
			align = Enum.TextXAlignment.Right, color = C.Gold, outline = 3, textSize = 18, zindex = 7,
		})
	end
	(outer :: TextButton).Activated:Connect(function()
		self:_PromptPurchase(item)
	end)
end

-- Reference rewardTile, reproduced exactly (green studded box + "Reward" + coin icon).
-- These are the store's decorative reward previews (not purchasable items), so
-- they carry no real item data — a bar-for-bar copy of RefExclusiveStore.
local function rewardTile(parent: Instance, x: number)
	local _, inner = RefSkin.box(parent, {
		size = UDim2.fromScale(0.232, 1), position = UDim2.fromScale(x, 0), anchor = Vector2.new(0, 0),
		gradTop = C.GreenTop, gradBottom = C.GreenBottom, border = C.GreenBorder, lightBg = GREEN_GAP, studs = true, gap = 4, zindex = 4,
	})
	RefSkin.label(inner, "Reward", {
		size = UDim2.fromScale(0.94, 0.26), position = UDim2.fromScale(0.5, 0.2), anchor = Vector2.new(0.5, 0.5),
		color = C.White, outline = 3, textSize = 26, zindex = 6,
	})
	RefSkin.icon(inner, RefSkin.Assets.cash, {
		size = UDim2.fromScale(0.6, 0.46), position = UDim2.fromScale(0.5, 0.66), anchor = Vector2.new(0.5, 0.5),
		zindex = 6,
	})
end

-- A reward row: a fixed-height frame of 4 tiles, laid out by the scroll's list
-- layout (offset height so the auto-canvas can measure it and every row scrolls
-- into reach — Scale heights are relative to the canvas and can't).
local ROW_H = 210
local function rewardRow(scroll: Instance, order: number)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(0.955, 0, 0, ROW_H)
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.LayoutOrder = order
	row.ZIndex = 4
	row.Parent = scroll
	for i = 1, 4 do
		rewardTile(row, (i - 1) * 0.256)
	end
end

function StoreScreen:_BuildContent()
	-- The exclusive store's shared modal shell (exact RefExclusiveStore.build args).
	-- Close is wired to hide THIS screen through the screen controller.
	local modal = RefSkin.Modal({
		parent = self.Root,
		title = TextConfig.Resolve("shop.title"),
		iconId = RefSkin.Assets.cart,
		aspect = 1.96,
		widthScale = 0.62,
		onClose = function()
			self.ScreenController:HideScreen("store")
		end,
	})
	self._modal = modal

	local scroll = RefSkin.scroll(modal.body, 1)
	-- Auto-grow the canvas to fit the featured panel + reward rows (fixed heights,
	-- laid out top to bottom) so everything scrolls into reach — the old Scale
	-- heights were relative to the canvas, leaving the bottom row unreachable.
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 12)
	list.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.Parent = scroll

	-- Featured pack panel (nested studded box holding the pack info + item cards).
	local featuredOuter, featured = RefSkin.box(scroll, {
		size = UDim2.new(0.955, 0, 0, 300),
		gradTop = C.FeaturedTop, gradBottom = C.FeaturedBottom, border = C.FeaturedBorder, lightBg = FEATURED_GAP, studs = true, gap = 5, zindex = 4,
	})
	featuredOuter.LayoutOrder = 1

	-- Real featured items drive the whole panel: item[1] is the pack headline (its
	-- name, price box), items[2..4] are the three showcase cards.
	local items = ShopConfig.GetItemsForCategory(self._categoryId)
	local headline = items[1]

	-- Pack Name (white) = the headline item's name.
	RefSkin.label(featured, headline and TextConfig.Resolve(headline.nameKey) or "", {
		size = UDim2.fromScale(0.26, 0.2), position = UDim2.fromScale(0.03, 0.1), anchor = Vector2.new(0, 0),
		align = Enum.TextXAlignment.Left, color = C.White, outline = 3, textSize = 36, zindex = 6,
	})
	-- Subtitle (gold) = the localized category label (shop.category.<id>).
	RefSkin.label(featured, TextConfig.Resolve("shop.category." .. self._categoryId), {
		size = UDim2.fromScale(0.26, 0.12), position = UDim2.fromScale(0.03, 0.34), anchor = Vector2.new(0, 0),
		align = Enum.TextXAlignment.Left, color = C.Gold, outline = 2.5, textSize = 20, zindex = 6,
	})
	-- Green pack price box — a clickable buy control for the headline item.
	local priceOuter, priceInner = RefSkin.box(featured, {
		button = true,
		size = UDim2.fromScale(0.2, 0.22), position = UDim2.fromScale(0.03, 0.56), anchor = Vector2.new(0, 0),
		gradTop = C.GreenTop, gradBottom = C.GreenBottom, border = C.GreenBorder, lightBg = GREEN_GAP, studs = false, gap = 3, zindex = 5,
	})
	if headline then
		(priceOuter :: TextButton).Activated:Connect(function()
			self:_PromptPurchase(headline)
		end)
		RefSkin.priceRow(priceInner, ShopConfig.FormatPrice(headline.price), currencyIcon(headline), {
			textSize = 26, outline = 2.5, zindex = 6,
		})
	end

	-- Three showcase item cards (real items 2..4) at the reference x positions.
	local cardXs = { 0.30, 0.525, 0.75 }
	for slot = 1, 3 do
		local item = items[slot + 1]
		if item then
			self:_ItemCard(featured, cardXs[slot], item, ITEM_EMOJI[(slot % #ITEM_EMOJI) + 1])
		end
	end

	-- Two decorative reward rows below (reproduced exactly from the reference).
	rewardRow(scroll, 2)
	rewardRow(scroll, 3)
end

-- Raise a confirm modal; on confirm, run the injected purchase (mirrors
-- ShopScreen:_PromptPurchase exactly, including the modal keys).
function StoreScreen:_PromptPurchase(item: SharedTypes.ShopItem)
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

function StoreScreen:_DoPurchase(item: SharedTypes.ShopItem)
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
end

function StoreScreen:_OnShow(data: any?)
	if data and data.balances then
		self._balances = data.balances
	end
end

function StoreScreen:Update(data: any)
	if data.balances then
		self._balances = data.balances
	end
end

return StoreScreen

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
	self._cards = {}
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
	panel:Create(self.Root, {
		titleKey = "shop.title",
		size = UDim2.fromScale(0.72, 0.9),
		onClose = function()
			self.ScreenController:HideScreen("shop")
		end,
	})

	-- Currency header (top-right of body).
	local currencyBar = UIStyler.Frame("Currencies")
	currencyBar.BackgroundTransparency = 1
	currencyBar.Size = UDim2.new(1, -20, 0, 34)
	currencyBar.Position = UDim2.fromOffset(10, 6)
	UIStyler.ListLayout({
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 10),
	}).Parent = currencyBar
	currencyBar.Parent = panel.Body
	for _, currency in ShopConfig.GetOrderedCurrencies() do
		local chip = UIStyler.TextLabel(currency.id)
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.Size = UDim2.fromScale(0, 1)
		chip.TextXAlignment = Enum.TextXAlignment.Right
		chip.Parent = currencyBar
		self._currencyLabels[currency.id] = chip
	end

	-- Category bar.
	local categoryBar = UIStyler.Frame("Categories")
	categoryBar.BackgroundTransparency = 1
	categoryBar.Size = UDim2.new(1, -20, 0, 40)
	categoryBar.Position = UDim2.fromOffset(10, 44)
	UIStyler.ListLayout({
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 8),
	}).Parent = categoryBar
	categoryBar.Parent = panel.Body
	self._categoryBar = categoryBar
	for i, category in ShopConfig.GetOrderedCategories() do
		local button = UIButtonComponent.new()
		button:Create(categoryBar, {
			textKey = category.nameKey,
			variant = category.id == self._categoryId and "Primary" or "Ghost",
			size = UDim2.new(0, 130, 1, 0),
			layoutOrder = i,
			onClick = function()
				self:_SelectCategory(category.id)
			end,
		})
		self._categoryButtons[category.id] = button
	end

	-- Scrolling item container.
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Items"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, -20, 1, -96)
	scroll.Position = UDim2.fromOffset(10, 90)
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
	-- Applied once; per-render we rebuild only the layout object, not this.
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = scroll
	self._scrollPad = pad

	-- Re-render when the scroll frame's width first becomes known / changes, so the
	-- CardTop grid height (which is derived from the real cell width) is correct.
	-- Guarded by _lastScrollW so a no-op resize doesn't loop.
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local w = scroll.AbsoluteSize.X
		if w > 0 and math.abs(w - (self._lastScrollW or 0)) > 1 then
			self._lastScrollW = w
			self:_RenderItems()
		end
	end)

	self:_RenderItems()
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
	self:_RenderItems()
end

-- Rebuild the item container from config using the active pack's layout.
function ShopScreen:_RenderItems()
	for _, card in self._cards do
		card:Destroy()
	end
	table.clear(self._cards)

	-- Clear any previous layout object.
	for _, child in self._scroll:GetChildren() do
		if child:IsA("UIGridLayout") or child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local pack = self.ThemeController:GetPack()
	local shopLayout = pack.Shop
	local spec = EntryLayoutConfig.Get(shopLayout.EntryLayout)

	if shopLayout.Container == "Grid" then
		local cols = shopLayout.Columns
		local cellPad = 10
		local cardHeight = shopLayout.CardHeight
		-- For CardTop specs (image-on-top), the image FILLS the card width and holds
		-- its aspect, so the card must be exactly tall enough for that image + the
		-- text block — no fixed height, no empty side space. We compute the real
		-- pixel cell width to derive that height. Other grid arrangements (Split)
		-- keep their configured CardHeight.
		if spec.arrangement == "CardTop" or spec.arrangement == "Overlay" then
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
				-- CardTop: square image over a text strip. To keep the whole card
				-- COMPACT and roughly square (AAA tiles aren't long strips), the card
				-- targets a pleasant ~1:1.25 ratio and the image gets the leftover
				-- height as a CENTRED square. On wide cards the square is a touch
				-- narrower than the card (small even margins, never a lonely edge);
				-- it never produces a lanky 1:2 card.
				-- Exact height of everything below the image (matches the renderer:
				-- surface pad 20 + tags 18 + name 22 + price 20 + spacer 2 + buy 38 +
				-- ~30 for the 6px ListLayout gaps). Kept accurate so Buy never clips.
				local textBlock = 20 + (spec.showTags and 18 or 0) + 22 + 20 + 2 + 38 + 30
				-- Keep the card compact & roughly square (AAA tiles, not long strips):
				-- aim ~1:1.2, and give the image the remaining height as a big centred
				-- square — clamped so it's never a tiny thumbnail nor a lanky card.
				local targetCardH = cellW * 1.2
				local imgH = math.clamp(targetCardH - textBlock, cellW * 0.62, cellW - 12)
				-- Square (or spec aspect): width = height * aspect, centred in the card.
				self._cardImageSizePx = math.floor(imgH * aspect)
				cardHeight = math.floor(imgH + textBlock)
			end
		else
			self._cardImageSizePx = nil
		end
		local cell = UIStyler.GridLayout(
			UDim2.new(1 / cols, -cellPad, 0, cardHeight),
			UDim2.fromOffset(cellPad, cellPad)
		)
		cell.Parent = self._scroll
	else
		UIStyler.ListLayout({ Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = self._scroll
	end

	local items = ShopConfig.GetItemsForCategory(self._categoryId)
	for i, item in items do
		local currency = ShopConfig.Currencies[item.currencyType]
		local card = UICardComponent.new()
		-- List rows get an explicit full-width size; grid cells are sized by the
		-- grid layout, so leave size nil there.
		local size = shopLayout.Container == "List" and UDim2.new(1, 0, 0, shopLayout.CardHeight) or nil
		card:Create(self._scroll, {
			item = item,
			spec = spec,
			currencyIcon = currency and currency.icon or "",
			affordable = ShopConfig.CanAfford(self._balances, item),
			layoutOrder = i,
			size = size,
			-- Exact image pixel width so a CardTop image fills the card with no gap.
			imageSizePx = self._cardImageSizePx,
			onBuy = function(boughtItem)
				self:_PromptPurchase(boughtItem)
			end,
		})
		card:PlayAnimation("Appear")
		table.insert(self._cards, card)
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
	self:_RenderItems()
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
	if data and data.categoryId then
		self._categoryId = data.categoryId
	end
	self:_RenderItems()
	self._panel:PlayAnimation("Appear")
end

function ShopScreen:Update(data: any)
	if data.balances then
		self._balances = data.balances
		-- Balances can arrive (currency pushes, boot snapshot) before the shop
		-- has ever been opened/built; just cache them until first show.
		if self._built then
			self:_RenderItems()
		end
	end
end

return ShopScreen

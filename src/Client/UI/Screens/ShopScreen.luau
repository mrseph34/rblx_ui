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
		size = UDim2.fromScale(0.7, 0.78),
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
		if spec.arrangement == "CardTop" then
			local scrollW = self._scroll.AbsoluteSize.X
			if scrollW <= 0 then
				scrollW = 700 -- pre-measure fallback; corrected on the next render
			end
			local cellW = (scrollW - cellPad * (cols - 1)) / cols
			local aspect = spec.imageAspect
			if not aspect or aspect <= 0 then
				aspect = 1
			end
			local imgW = cellW - 20 -- image fills the card content width (10px pad each side)
			local imgH = imgW / aspect
			-- Cache the pixel image width so each card sizes its image concretely.
			self._cardImageSizePx = math.floor(imgW)
			local textBlock = 20 -- card top+bottom padding
				+ (spec.showTags and 24 or 0)
				+ 24 -- name
				+ 22 -- price
				+ 42 -- buy
				+ 20 -- inter-row spacing
			cardHeight = math.floor(imgH + textBlock)
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

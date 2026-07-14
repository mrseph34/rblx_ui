--!strict
-- Shop LIST ROW — built through the EXACT reference skin (RefSkin) with the EXACT
-- values from Reference/RefServersShop.serverRow: same nested boxes, same gradient
-- colours, same sizes, positions, text sizes and outline thicknesses. Only the
-- text CONTENT is swapped from the reference's placeholders to the real item's
-- data (name / description / price / tag / category). This is the "Default" look
-- — a pixel copy of the reference we built, not a theme-token approximation, so
-- it deliberately does not respond to theme tokens.
--
-- Props: item, currencyIcon, affordable, owned?, onBuy

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local SharedTypes = require(ReplicatedStorage.Shared.Types)
local Types = require(script.Parent.Parent.Types)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local RefSkin = require(script.Parent.Parent.Reference.RefSkin)
local UIComponentBase = require(script.Parent.UIComponentBase)

local C = RefSkin.C
-- Reference-exact secondary colours (the lightBg "gap" tints RefServersShop uses).
local CARD_LIGHT = Color3.fromRGB(232, 242, 252)
local ICON_LIGHT = Color3.fromRGB(214, 230, 250)
local GREEN_LIGHT = Color3.fromRGB(224, 244, 218)

local UIListRowComponent = setmetatable({}, { __index = UIComponentBase })
UIListRowComponent.__index = UIListRowComponent

function UIListRowComponent.new()
	local self = UIComponentBase.new("UIListRow")
	return setmetatable(self, UIListRowComponent)
end

local function categoryText(item: SharedTypes.ShopItem): string
	if not item.category or item.category == "" then
		return ""
	end
	return TextConfig.Resolve("shop.category." .. item.category)
end

-- Gold label (the reference "Label: 0" slot): the item's description, else its
-- tag list, else its category — always informative.
local function labelText(item: SharedTypes.ShopItem): string
	if item.descriptionKey and item.descriptionKey ~= "" then
		return TextConfig.Resolve(item.descriptionKey)
	end
	if item.tags and #item.tags > 0 then
		return table.concat(item.tags, " · ")
	end
	return categoryText(item)
end

-- The currency's uploaded IMAGE icon (coins -> coin, gems -> purpleGem). Shown as
-- a real ImageLabel beside the price now, since an image can't live inside text.
local function currencyAsset(item: SharedTypes.ShopItem): string
	return item.currencyType == "Gems" and RefSkin.Assets.purpleGem or RefSkin.Assets.cash
end

function UIListRowComponent:_BuyText(): string
	if self.Props.owned then
		return TextConfig.Resolve("shop.owned")
	end
	-- Price NUMBER only — the currency is drawn as an image icon beside it (the
	-- old "000 💵" inline glyph can't be an image inside a text string).
	return ShopConfig.FormatPrice(self._item.price)
end

-- Green (buyable) or grey (owned / unaffordable) — reuses the reference's own
-- Green*/Gray* gradient stops so the disabled state stays on-palette.
function UIListRowComponent:_RefreshBuy()
	if self._buyLabel then
		self._buyLabel.Text = self:_BuyText()
	end
	-- Owned rows show just the word "Owned" (no price), so hide the currency icon.
	if self._buyIcon then
		self._buyIcon.Visible = not self.Props.owned
	end
	if self._buyGradient then
		local buyable = not self.Props.owned and self.Props.affordable ~= false
		self._buyGradient.Color = buyable and ColorSequence.new(C.GreenTop, C.GreenBottom)
			or ColorSequence.new(C.GrayTop, C.GrayBottom)
	end
end

function UIListRowComponent:_Build(props: Types.UIComponentProps)
	local item = props.item :: SharedTypes.ShopItem
	self._item = item
	if not props.size then
		self.Root.Size = UDim2.new(1, 0, 0, 124)
		self._baseSize = self.Root.Size
	end
	self.Root.BackgroundTransparency = 1

	-- The row box (reference serverRow outer): fills the Root slot (the ListLayout
	-- gaps + scroll padding give the spacing that serverRow's 0.95/0.3 did).
	local _, inner = RefSkin.box(self.Root, {
		size = UDim2.fromScale(1, 1), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5),
		gradTop = C.CardTop, gradBottom = C.CardBottom, border = C.CardBorder, lightBg = CARD_LIGHT, gap = 5, zindex = 2,
	})

	-- Image box (blue), left — a true SQUARE (1:1). The Size caps its WIDTH at
	-- 0.155 of the row; FitWithinMaxSize then makes it exactly that wide and just
	-- as tall, so it fills ~0.84 of the row height and sits flush-left of the name
	-- — the icon "fits as so" per the reference. (Row aspect is held near the
	-- reference's ~5.4:1 by the pack's CardHeight so this square clears the text.)
	local iconOuter, iconInner = RefSkin.box(inner, {
		size = UDim2.fromScale(0.155, 0.92), position = UDim2.fromScale(0.02, 0.5), anchor = Vector2.new(0, 0.5),
		gradTop = C.Blue, gradBottom = C.BlueDark, border = C.Outline, lightBg = ICON_LIGHT, gap = 3, zindex = 5,
	})
	local iconRatio = Instance.new("UIAspectRatioConstraint")
	iconRatio.AspectRatio = 1
	iconRatio.DominantAxis = Enum.DominantAxis.Height
	iconRatio.Parent = iconOuter
	if item.iconId ~= "" then
		-- Real art fits INSIDE the box with a small margin, keeping its own aspect
		-- (ScaleType.Fit) — the server-rack icon "fits as so" per the reference.
		RefSkin.icon(iconInner, item.iconId, {
			size = UDim2.fromScale(0.9, 0.9), position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5), zindex = 7,
		})
	else
		-- Item-image PLACEHOLDER — the reference's monitor glyph (items ship no
		-- real iconId yet), sized to fill the now-larger box.
		RefSkin.label(iconInner, "🖥️", { outline = 0, textSize = 88, zindex = 7 })
	end

	-- Name (white). Starts right of the larger icon box (~0.175) with a clear gap.
	RefSkin.label(inner, TextConfig.Resolve(item.nameKey), {
		size = UDim2.fromScale(0.40, 0.3), position = UDim2.fromScale(0.21, 0.24), anchor = Vector2.new(0, 0.5),
		align = Enum.TextXAlignment.Left, color = C.White, outline = 3, textSize = 36, zindex = 6,
	})
	-- Gold label = description.
	RefSkin.label(inner, labelText(item), {
		size = UDim2.fromScale(0.40, 0.36), position = UDim2.fromScale(0.21, 0.66), anchor = Vector2.new(0, 0.5),
		align = Enum.TextXAlignment.Left, color = C.Gold, outline = 3.5, textSize = 44, zindex = 6,
	})

	-- Green price/buy box (clickable) = the reference cash box.
	local buyOuter, buyInner = RefSkin.box(inner, {
		button = true, size = UDim2.fromScale(0.14, 0.34), position = UDim2.fromScale(0.64, 0.12), anchor = Vector2.new(0, 0),
		gradTop = C.GreenTop, gradBottom = C.GreenBottom, border = C.GreenBorder, lightBg = GREEN_LIGHT, studs = false, gap = 3, zindex = 5,
	})
	-- The buy box inner lays out horizontally: [price number][currency icon], both
	-- centred. (A currency image can't be baked into the price text, so it becomes a
	-- sibling ImageLabel — rule 2.)
	local buyLayout = Instance.new("UIListLayout")
	buyLayout.FillDirection = Enum.FillDirection.Horizontal
	buyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buyLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	buyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	buyLayout.Padding = UDim.new(0.05, 0)
	buyLayout.Parent = buyInner
	-- Price number (white + outlined, exactly as before) — AutomaticSize.X so it
	-- keeps only the width the digits need, leaving room for the icon beside it.
	self._buyLabel = RefSkin.label(buyInner, self:_BuyText(), { color = C.White, outline = 2.5, textSize = 28, zindex = 6, layoutOrder = 1 })
	self._buyLabel.Size = UDim2.fromScale(0, 0.66)
	self._buyLabel.AutomaticSize = Enum.AutomaticSize.X
	-- Currency icon: coin for Coins, purpleGem for Gems. A square (1:1 off its
	-- height) that sits to the right of the number.
	self._buyIcon = RefSkin.icon(buyInner, currencyAsset(item), { size = UDim2.fromScale(1, 0.66), zindex = 6, layoutOrder = 2 })
	local buyIconRatio = Instance.new("UIAspectRatioConstraint")
	buyIconRatio.AspectRatio = 1
	buyIconRatio.DominantAxis = Enum.DominantAxis.Height
	buyIconRatio.Parent = self._buyIcon
	self._buyGradient = buyInner:FindFirstChildOfClass("UIGradient")
	self:_Connect((buyOuter :: TextButton).Activated, function()
		if self.Props.onBuy then
			self.Props.onBuy(self._item)
		end
	end)

	-- Blue box = the reference robux box; shows the item's primary tag (hidden if none).
	local tag = item.tags and item.tags[1] or nil
	local tagOuter, tagInner = RefSkin.box(inner, {
		size = UDim2.fromScale(0.14, 0.34), position = UDim2.fromScale(0.82, 0.12), anchor = Vector2.new(0, 0),
		gradTop = C.Blue, gradBottom = C.BlueDark, border = C.BlueDark, lightBg = ICON_LIGHT, studs = false, gap = 3, zindex = 5,
	})
	RefSkin.label(tagInner, tag and string.upper(tag) or "", { color = C.White, outline = 2.5, textSize = 28, zindex = 6 })
	tagOuter.Visible = tag ~= nil

	-- Sub-label (dark ink, no outline — exactly like the reference) = category.
	RefSkin.label(inner, categoryText(item), {
		size = UDim2.fromScale(0.34, 0.28), position = UDim2.fromScale(0.97, 0.72), anchor = Vector2.new(1, 0.5),
		align = Enum.TextXAlignment.Right, color = C.Ink, outline = 0, textSize = 28, zindex = 6,
	})

	self:_RefreshBuy()
end

-- Patch affordability / owned in place without rebuilding.
function UIListRowComponent:Update(props: { affordable: boolean?, owned: boolean? })
	if props.affordable ~= nil then
		self.Props.affordable = props.affordable
	end
	if props.owned ~= nil then
		self.Props.owned = props.owned
	end
	self:_RefreshBuy()
end

-- The row is a pixel-exact RefSkin reproduction with its own hardcoded colours and
-- per-label outlines. It intentionally does NOT theme (and skips the base outline
-- pass, which would add a SECOND stroke on top of RefSkin's).
function UIListRowComponent:ApplyTheme(theme: Types.UITheme?)
	self.Theme = theme
end

return UIListRowComponent

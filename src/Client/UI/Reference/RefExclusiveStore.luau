--!strict
-- Reference "store" layout, scrollable, TEMPLATE text. Every element is the
-- shared nested box: dark border -> light gap -> studded gradient -> content.

local RefSkin = require(script.Parent.RefSkin)
local C = RefSkin.C
local RefExclusiveStore = {}

-- Item cards are a SATURATED blue GRADIENT (vivid top -> deep bottom, no studs)
-- so the white text reads with high contrast; dark border, light gap frame.
local CARD_TOP = Color3.fromRGB(86, 172, 250)
local CARD_BOTTOM = Color3.fromRGB(30, 96, 200)
local CARD_BORDER = Color3.fromRGB(28, 84, 168)
local CARD_GAP = Color3.fromRGB(198, 224, 250)

local function itemCard(parent: Instance, x: number, title: string, value: string, icon: string)
	local _, inner = RefSkin.box(parent, {
		size = UDim2.fromScale(0.208, 0.86), position = UDim2.fromScale(x, 0.5), anchor = Vector2.new(0, 0.5),
		gradTop = CARD_TOP, gradBottom = CARD_BOTTOM, border = CARD_BORDER, lightBg = CARD_GAP, gap = 4, zindex = 4,
	})
	-- Name flush at the TOP edge, big + strongly outlined.
	RefSkin.label(inner, title, {
		size = UDim2.fromScale(0.96, 0.22), position = UDim2.fromScale(0.5, 0.1), anchor = Vector2.new(0.5, 0.5),
		color = C.White, outline = 4, textSize = 36, zindex = 6,
	})
	-- Item art directly on the card (no inner box); emoji placeholder for real art.
	RefSkin.label(inner, icon, {
		size = UDim2.fromScale(0.76, 0.46), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5),
		outline = 0, textSize = 96, zindex = 6,
	})
	-- Price flush at the BOTTOM edge, big + strongly outlined.
	RefSkin.label(inner, value, {
		size = UDim2.fromScale(0.96, 0.22), position = UDim2.fromScale(0.5, 0.9), anchor = Vector2.new(0.5, 0.5),
		color = C.White, outline = 4, textSize = 36, zindex = 6,
	})
end

local function rewardTile(parent: Instance, x: number)
	local _, inner = RefSkin.box(parent, {
		size = UDim2.fromScale(0.232, 1), position = UDim2.fromScale(x, 0), anchor = Vector2.new(0, 0),
		gradTop = C.GreenTop, gradBottom = C.GreenBottom, border = C.GreenBorder, lightBg = Color3.fromRGB(224, 244, 218), studs = true, gap = 4, zindex = 4,
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

local function rewardRow(scroll: Instance, y: number)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(0.955, 0.34)
	row.Position = UDim2.fromScale(0.5, y)
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.ZIndex = 4
	row.Parent = scroll
	for i = 1, 4 do
		rewardTile(row, (i - 1) * 0.256)
	end
end

function RefExclusiveStore.build(parent: Instance): RefSkin.Modal
	local modal = RefSkin.Modal({
		parent = parent, title = "Store Title", iconId = RefSkin.Assets.cart, aspect = 1.96, widthScale = 0.62,
	})
	local scroll = RefSkin.scroll(modal.body, 1.3)

	-- Featured panel (a nested box holding the pack info + item cards).
	local _, featured = RefSkin.box(scroll, {
		size = UDim2.fromScale(0.955, 0.42), position = UDim2.fromScale(0.5, 0.02), anchor = Vector2.new(0.5, 0),
		gradTop = C.FeaturedTop, gradBottom = C.FeaturedBottom, border = C.FeaturedBorder, lightBg = Color3.fromRGB(206, 226, 248), studs = true, gap = 5, zindex = 4,
	})

	RefSkin.label(featured, "Pack Name", {
		size = UDim2.fromScale(0.26, 0.2), position = UDim2.fromScale(0.03, 0.1), anchor = Vector2.new(0, 0),
		align = Enum.TextXAlignment.Left, color = C.White, outline = 3, textSize = 36, zindex = 6,
	})
	RefSkin.label(featured, "Subtitle", {
		size = UDim2.fromScale(0.26, 0.12), position = UDim2.fromScale(0.03, 0.34), anchor = Vector2.new(0, 0),
		align = Enum.TextXAlignment.Left, color = C.Gold, outline = 2.5, textSize = 20, zindex = 6,
	})
	local _, priceInner = RefSkin.box(featured, {
		size = UDim2.fromScale(0.2, 0.22), position = UDim2.fromScale(0.03, 0.56), anchor = Vector2.new(0, 0),
		gradTop = C.GreenTop, gradBottom = C.GreenBottom, border = C.GreenBorder, lightBg = Color3.fromRGB(224, 244, 218), studs = false, gap = 3, zindex = 5,
	})
	RefSkin.priceRow(priceInner, "000", RefSkin.Assets.robux, { textSize = 26, outline = 2.5, zindex = 6 })

	itemCard(featured, 0.30, "Item Name", "0000", "🛰️")
	itemCard(featured, 0.525, "Item Name", "0000", "📡")
	itemCard(featured, 0.75, "Item Name", "0000", "👟")

	rewardRow(scroll, 0.48)
	rewardRow(scroll, 0.86)

	return modal
end

return RefExclusiveStore

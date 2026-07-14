--!strict
-- Reference "priced list", scrollable, TEMPLATE text. Every element is the
-- shared nested box (dark border -> light gap -> studded gradient -> content).

local RefSkin = require(script.Parent.RefSkin)
local C = RefSkin.C
local RefServersShop = {}

local CARD_LIGHT = Color3.fromRGB(232, 242, 252)

local function serverRow(parent: Instance, y: number)
	local _, inner = RefSkin.box(parent, {
		size = UDim2.fromScale(0.95, 0.3), position = UDim2.fromScale(0.5, y), anchor = Vector2.new(0.5, 0),
		gradTop = C.CardTop, gradBottom = C.CardBottom, border = C.CardBorder, lightBg = CARD_LIGHT, gap = 5, zindex = 4,
	})

	local _, iconInner = RefSkin.box(inner, {
		size = UDim2.fromScale(0.13, 0.82), position = UDim2.fromScale(0.02, 0.5), anchor = Vector2.new(0, 0.5),
		gradTop = C.Blue, gradBottom = C.BlueDark, border = C.Outline, lightBg = Color3.fromRGB(214, 230, 250), gap = 3, zindex = 5,
	})
	RefSkin.label(iconInner, "🖥️", { outline = 0, textSize = 48, zindex = 7 })

	RefSkin.label(inner, "Item Name", {
		size = UDim2.fromScale(0.42, 0.3), position = UDim2.fromScale(0.18, 0.24), anchor = Vector2.new(0, 0.5),
		align = Enum.TextXAlignment.Left, color = C.White, outline = 3, textSize = 36, zindex = 6,
	})
	RefSkin.label(inner, "Label: 0", {
		size = UDim2.fromScale(0.42, 0.36), position = UDim2.fromScale(0.18, 0.66), anchor = Vector2.new(0, 0.5),
		align = Enum.TextXAlignment.Left, color = C.Gold, outline = 3.5, textSize = 44, zindex = 6,
	})

	local _, cashInner = RefSkin.box(inner, {
		size = UDim2.fromScale(0.14, 0.34), position = UDim2.fromScale(0.64, 0.12), anchor = Vector2.new(0, 0),
		gradTop = C.GreenTop, gradBottom = C.GreenBottom, border = C.GreenBorder, lightBg = Color3.fromRGB(224, 244, 218), studs = false, gap = 3, zindex = 5,
	})
	RefSkin.priceRow(cashInner, "000", RefSkin.Assets.cash, { textSize = 28, outline = 2.5, zindex = 6 })

	local _, robuxInner = RefSkin.box(inner, {
		size = UDim2.fromScale(0.14, 0.34), position = UDim2.fromScale(0.82, 0.12), anchor = Vector2.new(0, 0),
		gradTop = C.Blue, gradBottom = C.BlueDark, border = C.BlueDark, lightBg = Color3.fromRGB(214, 230, 250), studs = false, gap = 3, zindex = 5,
	})
	RefSkin.priceRow(robuxInner, "00", RefSkin.Assets.robux, { textSize = 28, outline = 2.5, zindex = 6 })

	RefSkin.label(inner, "Sub-label: 0 💾", {
		size = UDim2.fromScale(0.34, 0.28), position = UDim2.fromScale(0.97, 0.72), anchor = Vector2.new(1, 0.5),
		align = Enum.TextXAlignment.Right, color = C.Ink, outline = 0, textSize = 28, zindex = 6,
	})
end

function RefServersShop.build(parent: Instance): RefSkin.Modal
	local modal = RefSkin.Modal({
		parent = parent, title = "Shop Title", icon = "🖥️", aspect = 2.22, widthScale = 0.6,
	})

	local scroll = RefSkin.scroll(modal.body, 1.42)
	scroll.Size = UDim2.fromScale(1, 0.85)
	for i = 1, 4 do
		serverRow(scroll, 0.02 + (i - 1) * 0.34)
	end

	-- Fixed footer.
	local footer = Instance.new("Frame")
	footer.BackgroundTransparency = 1
	footer.AnchorPoint = Vector2.new(0.5, 1)
	footer.Position = UDim2.fromScale(0.5, 1)
	footer.Size = UDim2.fromScale(1, 0.15)
	footer.ZIndex = 6
	footer.Parent = modal.body

	local _, btnInner = RefSkin.box(footer, {
		button = true, size = UDim2.fromScale(0.26, 0.72), position = UDim2.fromScale(0.03, 0.5), anchor = Vector2.new(0, 0.5),
		gradTop = Color3.fromRGB(255, 186, 66), gradBottom = Color3.fromRGB(238, 150, 30), border = Color3.fromRGB(170, 96, 16),
		lightBg = Color3.fromRGB(255, 236, 202), studs = false, gap = 4, zindex = 6,
	})
	RefSkin.label(btnInner, "Button", { color = C.White, outline = 2.5, textSize = 26, zindex = 8 })

	RefSkin.label(footer, "Timer: 00:00", {
		size = UDim2.fromScale(0.4, 0.6), position = UDim2.fromScale(0.97, 0.5), anchor = Vector2.new(1, 0.5),
		align = Enum.TextXAlignment.Right, color = C.White, outline = 3, textSize = 28, zindex = 7,
	})

	return modal
end

return RefServersShop

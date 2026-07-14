--!strict
-- Reference main HUD (full-screen). Every control uses the shared nested box
-- (dark border -> light gap -> gradient inner -> content). TEMPLATE text.

local UIStyler = require(script.Parent.Parent.UIStyler)
local RefSkin = require(script.Parent.RefSkin)

local C = RefSkin.C
local RefHUD = {}

local LIGHT = Color3.fromRGB(246, 249, 254) -- light frame colour in the gap

local function squareBox(box: GuiObject)
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = box
end

local function tabButton(root: Instance, size: UDim2, pos: UDim2, anchor: Vector2, gTop: Color3, gBottom: Color3, border: Color3, text: string, textSize: number)
	local _, inner = RefSkin.box(root, {
		button = true, size = size, position = pos, anchor = anchor,
		gradTop = gTop, gradBottom = gBottom, border = border, lightBg = LIGHT, studs = false, gap = 5, zindex = 2,
	})
	RefSkin.label(inner, text, { color = C.White, outline = 2.5, textSize = textSize, zindex = 5 })
end

local function iconButton(root: Instance, pos: UDim2, anchor: Vector2, icon: string, label: string, gTop: Color3, gBottom: Color3, border: Color3)
	local holder = UIStyler.Frame("IconBtn")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(0.075, 0.16)
	holder.Position = pos
	holder.AnchorPoint = anchor
	holder.Parent = root

	local box, inner = RefSkin.box(holder, {
		button = true, size = UDim2.fromScale(1, 0.74), position = UDim2.fromScale(0.5, 0), anchor = Vector2.new(0.5, 0),
		gradTop = gTop, gradBottom = gBottom, border = border, lightBg = LIGHT, studs = false, gap = 5, zindex = 2,
	})
	squareBox(box)
	-- `icon` is either an uploaded image asset id or an emoji placeholder (no asset
	-- exists yet, e.g. 📖 / 🔨) — render the former as an image, the latter as text.
	if string.match(icon, "^rbxassetid://") then
		RefSkin.icon(inner, icon, { zindex = 5 })
	else
		RefSkin.label(inner, icon, { outline = 0, textSize = 52, zindex = 5 })
	end

	RefSkin.label(holder, label, {
		size = UDim2.fromScale(1.3, 0.24), position = UDim2.fromScale(0.5, 0.78), anchor = Vector2.new(0.5, 0),
		color = C.White, outline = 3, textSize = 24, zindex = 5,
	})
end

local function readout(root: Instance, pos: UDim2, value: string, valueColor: Color3, icon: string)
	local holder = UIStyler.Frame("Readout")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(0.2, 0.16)
	holder.Position = pos
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Parent = root
	RefSkin.label(holder, "Label " .. icon, {
		size = UDim2.fromScale(1, 0.42), position = UDim2.fromScale(0.5, 0), anchor = Vector2.new(0.5, 0),
		color = C.White, outline = 3, textSize = 26, zindex = 5,
	})
	RefSkin.label(holder, value, {
		size = UDim2.fromScale(1, 0.5), position = UDim2.fromScale(0.5, 0.46), anchor = Vector2.new(0.5, 0),
		color = valueColor, outline = 3.5, textSize = 40, zindex = 5,
	})
end

local function counter(root: Instance, pos: UDim2, badgeId: string, value: string, bTop: Color3, bBottom: Color3)
	local holder = UIStyler.Frame("Counter")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(0.14, 0.075)
	holder.Position = pos
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Parent = root

	local box, inner = RefSkin.box(holder, {
		size = UDim2.fromScale(0.38, 1), position = UDim2.fromScale(0, 0.5), anchor = Vector2.new(0, 0.5),
		gradTop = bTop, gradBottom = bBottom, border = C.Outline, lightBg = LIGHT, studs = false, gap = 4, zindex = 2,
	})
	squareBox(box)
	RefSkin.icon(inner, badgeId, { zindex = 5 })

	RefSkin.label(holder, value, {
		size = UDim2.fromScale(0.58, 0.86), position = UDim2.fromScale(0.42, 0.5), anchor = Vector2.new(0, 0.5),
		align = Enum.TextXAlignment.Left, color = C.White, outline = 3.5, textSize = 40, zindex = 5,
	})
end

local function sideDeal(root: Instance, pos: UDim2, iconId: string, price: string)
	local holder = UIStyler.Frame("Deal")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(0.08, 0.22)
	holder.Position = pos
	holder.AnchorPoint = Vector2.new(1, 0.5)
	holder.Parent = root
	RefSkin.label(holder, "Deal", {
		size = UDim2.fromScale(1.1, 0.18), position = UDim2.fromScale(0.5, 0), anchor = Vector2.new(0.5, 0),
		color = C.White, outline = 3, textSize = 22, zindex = 5,
	})
	local _, artInner = RefSkin.box(holder, {
		size = UDim2.fromScale(0.9, 0.5), position = UDim2.fromScale(0.5, 0.22), anchor = Vector2.new(0.5, 0),
		gradTop = C.Blue, gradBottom = C.BlueDark, border = C.Outline, lightBg = LIGHT, gap = 4, zindex = 2,
	})
	RefSkin.icon(artInner, iconId, { zindex = 5 })

	local _, priceInner = RefSkin.box(holder, {
		size = UDim2.fromScale(0.85, 0.2), position = UDim2.fromScale(0.5, 1), anchor = Vector2.new(0.5, 1),
		gradTop = C.GreenTop, gradBottom = C.GreenBottom, border = C.GreenBorder, lightBg = LIGHT, studs = false, gap = 3, zindex = 2,
	})
	-- Price was "<n> ⬡" (robux glyph inline); split into number + robux image.
	RefSkin.priceRow(priceInner, price, RefSkin.Assets.robux, { textSize = 22, outline = 2.5, zindex = 5, padding = 3 })
end

function RefHUD.build(parent: Instance): { root: Frame }
	local root = UIStyler.Frame("HUD")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = parent

	tabButton(root, UDim2.fromScale(0.2, 0.06), UDim2.fromScale(0.34, 0.02), Vector2.new(1, 0),
		Color3.fromRGB(74, 150, 240), Color3.fromRGB(40, 110, 210), Color3.fromRGB(24, 78, 168), "Tab 1", 26)
	tabButton(root, UDim2.fromScale(0.16, 0.08), UDim2.fromScale(0.5, 0.015), Vector2.new(0.5, 0),
		Color3.fromRGB(255, 190, 70), Color3.fromRGB(238, 150, 30), Color3.fromRGB(170, 96, 16), "Tab 2", 34)
	tabButton(root, UDim2.fromScale(0.14, 0.06), UDim2.fromScale(0.66, 0.02), Vector2.new(0, 0),
		C.GreenTop, C.GreenBottom, C.GreenBorder, "Tab 3", 30)

	readout(root, UDim2.fromScale(0.43, 0.16), "0000", Color3.fromRGB(120, 232, 110), "🏰")
	readout(root, UDim2.fromScale(0.6, 0.16), "0000", Color3.fromRGB(196, 130, 250), "📡")

	counter(root, UDim2.fromScale(0.02, 0.34), RefSkin.Assets.cash, "0000", Color3.fromRGB(255, 208, 92), Color3.fromRGB(236, 170, 40))
	counter(root, UDim2.fromScale(0.02, 0.43), RefSkin.Assets.purpleGem, "0000", Color3.fromRGB(214, 128, 214), Color3.fromRGB(168, 78, 168))

	iconButton(root, UDim2.fromScale(0.03, 0.56), Vector2.new(0, 0), RefSkin.Assets.cart, "Label",
		Color3.fromRGB(238, 96, 96), Color3.fromRGB(206, 48, 48), C.RedDark)
	iconButton(root, UDim2.fromScale(0.03, 0.72), Vector2.new(0, 0), "📖", "Label",
		Color3.fromRGB(120, 168, 232), Color3.fromRGB(70, 120, 200), Color3.fromRGB(28, 78, 168))
	iconButton(root, UDim2.fromScale(0.03, 0.88), Vector2.new(0, 0), RefSkin.Assets.settings, "Label",
		Color3.fromRGB(120, 168, 232), Color3.fromRGB(70, 120, 200), Color3.fromRGB(28, 78, 168))

	iconButton(root, UDim2.fromScale(0.965, 0.6), Vector2.new(1, 0), "🔨", "Label",
		Color3.fromRGB(120, 168, 232), Color3.fromRGB(70, 120, 200), Color3.fromRGB(28, 78, 168))
	iconButton(root, UDim2.fromScale(0.965, 0.78), Vector2.new(1, 0), RefSkin.Assets.wrong, "Label",
		Color3.fromRGB(238, 96, 96), Color3.fromRGB(206, 48, 48), C.RedDark)

	sideDeal(root, UDim2.fromScale(0.99, 0.2), RefSkin.Assets.blueGem, "00")
	sideDeal(root, UDim2.fromScale(0.99, 0.42), RefSkin.Assets.gift, "00")

	return { root = root }
end

return RefHUD

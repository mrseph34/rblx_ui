--!strict
-- Reference "collection" layout: category header over a scrollable 5-column tile
-- grid (unlocked / locked) + a fixed progress bar footer. TEMPLATE text. Every
-- tile is the shared nested box (dark border -> light gap -> studded gradient).

local RefSkin = require(script.Parent.RefSkin)
local C = RefSkin.C
local RefIndex = {}

local function tile(parent: Instance, col: number, rowIndex: number, locked: boolean)
	local pos = UDim2.fromScale(0.035 + col * 0.186, 0.02 + rowIndex * 0.46)
	local size = UDim2.fromScale(0.17, 0.42)
	local _, inner
	if locked then
		_, inner = RefSkin.box(parent, {
			size = size, position = pos, anchor = Vector2.new(0, 0),
			gradTop = Color3.fromRGB(168, 176, 186), gradBottom = Color3.fromRGB(132, 140, 150),
			border = Color3.fromRGB(96, 102, 112), lightBg = Color3.fromRGB(214, 218, 224), gap = 4, zindex = 4,
		})
	else
		_, inner = RefSkin.box(parent, {
			size = size, position = pos, anchor = Vector2.new(0, 0),
			gradTop = Color3.fromRGB(96, 168, 244), gradBottom = Color3.fromRGB(52, 122, 214),
			border = Color3.fromRGB(30, 92, 176), lightBg = Color3.fromRGB(210, 230, 250), gap = 4, zindex = 4,
		})
	end
	RefSkin.label(inner, "Item", {
		size = UDim2.fromScale(0.92, 0.24), position = UDim2.fromScale(0.5, 0.14), anchor = Vector2.new(0.5, 0.5),
		color = C.White, outline = 3, textSize = 26, zindex = 6,
	})
	RefSkin.label(inner, "📡", {
		size = UDim2.fromScale(0.7, 0.5), position = UDim2.fromScale(0.5, 0.62), anchor = Vector2.new(0.5, 0.5),
		outline = 0, textSize = 60, zindex = 6,
	})
end

function RefIndex.build(parent: Instance): RefSkin.Modal
	local modal = RefSkin.Modal({
		parent = parent, title = "Index Title", icon = "📖", aspect = 1.72, widthScale = 0.6,
	})
	local body = modal.body

	RefSkin.label(body, "Category", {
		size = UDim2.fromScale(1, 0.1), position = UDim2.fromScale(0.5, 0.02), anchor = Vector2.new(0.5, 0),
		color = C.White, outline = 3.5, textSize = 40, zindex = 6,
	})

	local scroll = RefSkin.scroll(body, 1)
	scroll.Size = UDim2.fromScale(1, 0.72)
	scroll.Position = UDim2.fromScale(0, 0.14)
	-- Lay the tiles out with a grid and let the canvas auto-grow to fit EVERY row.
	-- (The old Scale-positioned tiles were sized relative to the canvas, so the
	-- bottom rows sat past the scrollable region and were unreachable.) The grid
	-- overrides each tile's own Size/Position, so `tile` needs no other change.
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromScale(0.018, 0.04)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroll
	-- SQUARE tiles: the cell WIDTH is 0.176 of the scroll; lock its HEIGHT to that
	-- same pixel value (an offset) so every tile is a true square whatever the
	-- panel's aspect. Re-run on resize since the offset is derived from live width.
	local function squareCells()
		grid.CellSize = UDim2.new(0.176, 0, 0, 0.176 * scroll.AbsoluteSize.X)
	end
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(squareCells)
	squareCells()
	for i = 1, 15 do
		tile(scroll, (i - 1) % 5, math.floor((i - 1) / 5), i % 4 == 0)
	end

	-- Fixed progress bar + badge footer.
	local barWrap = Instance.new("Frame")
	barWrap.AnchorPoint = Vector2.new(0, 1)
	barWrap.Position = UDim2.fromScale(0.03, 0.99)
	barWrap.Size = UDim2.fromScale(0.82, 0.08)
	barWrap.BackgroundColor3 = Color3.fromRGB(150, 190, 236)
	barWrap.ZIndex = 6
	barWrap.ClipsDescendants = true
	local wc = Instance.new("UICorner")
	wc.CornerRadius = UDim.new(1, 0)
	wc.Parent = barWrap
	RefSkin.outline(barWrap, C.CardBorder, 2)
	barWrap.Parent = body

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0.26, 1)
	fill.ZIndex = 6
	RefSkin.gradientFill(fill, Color3.fromRGB(255, 206, 92), Color3.fromRGB(232, 158, 40))
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = fill
	fill.Parent = barWrap
	RefSkin.label(barWrap, "00%", { color = C.White, outline = 2.5, textSize = 22, zindex = 7 })

	local _, badgeInner = RefSkin.box(body, {
		size = UDim2.fromScale(0.1, 0.08), position = UDim2.fromScale(0.99, 0.99), anchor = Vector2.new(1, 1),
		gradTop = C.GreenTop, gradBottom = C.GreenBottom, border = C.GreenBorder, lightBg = Color3.fromRGB(224, 244, 218), studs = false, gap = 3, zindex = 6,
	})
	RefSkin.label(badgeInner, "x0", { color = C.White, outline = 2.5, textSize = 26, zindex = 8 })

	return modal
end

return RefIndex

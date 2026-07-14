--!strict
-- EXACT-REPRODUCTION skin for the reference "server tycoon" UI.
--
-- Every value is measured off the reference screenshots and hard-coded — this is
-- a bar-for-bar copy, not a re-skinnable abstraction, so it bypasses the theme
-- system. Each reference screen builds its shell from RefSkin.Modal + fills body.
--
-- SURFACE CONSTRUCTION (per the reference): every panel is layered
--   1. studs IMAGE layer   (tiled texture, bottom)
--   2. GRADIENT layer      (semi-transparent, over the image)
--   3. BORDER              (crisp stroke)
-- with CRISP corners (small radius, not blobby). RefSkin.surface() builds that.

local UIStyler = require(script.Parent.Parent.UIStyler)

local RefSkin = {}

-- Studs texture supplied by the user.
local STUD = "rbxassetid://127591984186114"
-- Crisp corner radius used everywhere. 0 = square (the reference look).
RefSkin.CORNER = 0

-- ---- measured palette -------------------------------------------------
RefSkin.C = {
	TitleTop = Color3.fromRGB(96, 178, 246),
	TitleBottom = Color3.fromRGB(40, 120, 226),
	BodyTop = Color3.fromRGB(226, 240, 252),
	BodyBottom = Color3.fromRGB(190, 218, 246),
	ModalBorder = Color3.fromRGB(255, 255, 255),
	HeaderBorder = Color3.fromRGB(30, 92, 176),

	FeaturedTop = Color3.fromRGB(140, 178, 232),
	FeaturedBottom = Color3.fromRGB(98, 142, 210),
	FeaturedBorder = Color3.fromRGB(178, 208, 246),
	CardTop = Color3.fromRGB(224, 238, 251),
	CardBottom = Color3.fromRGB(196, 222, 246),
	CardBorder = Color3.fromRGB(120, 165, 220),

	White = Color3.fromRGB(255, 255, 255),
	Outline = Color3.fromRGB(19, 42, 92),
	Ink = Color3.fromRGB(24, 46, 96),

	Gold = Color3.fromRGB(255, 197, 66),
	GreenTop = Color3.fromRGB(126, 214, 92),
	GreenBottom = Color3.fromRGB(84, 176, 60),
	GreenBorder = Color3.fromRGB(52, 132, 40),
	Red = Color3.fromRGB(228, 62, 62),
	RedDark = Color3.fromRGB(150, 30, 30),
	Robux = Color3.fromRGB(96, 190, 80),
	Blue = Color3.fromRGB(64, 132, 236),
	BlueDark = Color3.fromRGB(28, 78, 168),
	PurpleTop = Color3.fromRGB(168, 84, 234),
	PurpleBottom = Color3.fromRGB(96, 42, 152),
	Scroll = Color3.fromRGB(120, 165, 220),

	-- Dark "settings" chrome
	SetHeaderTop = Color3.fromRGB(30, 58, 94),
	SetHeaderBottom = Color3.fromRGB(16, 38, 66),
	SetBodyTop = Color3.fromRGB(46, 78, 114),
	SetBodyBottom = Color3.fromRGB(34, 60, 92),
	SetRowTop = Color3.fromRGB(58, 92, 130),
	SetRowBottom = Color3.fromRGB(44, 74, 108),
	SetRowBorder = Color3.fromRGB(96, 132, 170),
	GrayTop = Color3.fromRGB(178, 186, 196),
	GrayBottom = Color3.fromRGB(120, 128, 138),
}

RefSkin.Font = Font.fromEnum(Enum.Font.FredokaOne)

-- Uploaded image icons (replace the emoji placeholders where one applies).
RefSkin.Assets = {
	coin = "rbxassetid://117038076877938",
	cash = "rbxassetid://112721837354492",
	robux = "rbxassetid://133897782957449",
	settings = "rbxassetid://117673024155406",
	cart = "rbxassetid://80688093308394",
	gift = "rbxassetid://81289952408347",
	purpleGem = "rbxassetid://128674131529876",
	wrong = "rbxassetid://110511319123543",
	blueGem = "rbxassetid://122588485223646",
}

-- An image icon placed exactly like RefSkin.label (same size/position/anchor/
-- zindex opts) — the drop-in replacement for an emoji label. ScaleType.Fit keeps
-- the art's own aspect inside the given box.
export type IconOpts = {
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	zindex: number?,
	layoutOrder: number?,
}
function RefSkin.icon(parent: Instance, imageId: string, opts: IconOpts?): ImageLabel
	local o = opts or {}
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Image = imageId
	img.ScaleType = Enum.ScaleType.Fit
	img.Size = o.size or UDim2.fromScale(1, 1)
	if o.position then
		img.Position = o.position
	end
	if o.anchor then
		img.AnchorPoint = o.anchor
	end
	img.ZIndex = o.zindex or 5
	if o.layoutOrder then
		img.LayoutOrder = o.layoutOrder
	end
	img.Parent = parent
	return img
end

-- Inline currency prices ("99 💰") can't put an image inside text, so the price
-- box instead holds a centered horizontal row: the NUMBER as a TextLabel (white +
-- outlined, auto-width) followed by a small SQUARE currency icon (sized off the
-- box height via an aspect constraint). `box` is the bounded frame to fill — a
-- RefSkin.box inner or a sized holder Frame.
export type PriceOpts = {
	textSize: number?,
	outline: number?,
	zindex: number?,
	padding: number?,
}
function RefSkin.priceRow(box: GuiObject, numberText: string, currencyId: string, opts: PriceOpts?)
	local o = opts or {}
	local z = o.zindex or 6
	local ts = o.textSize or 26

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, o.padding or 4)
	layout.Parent = box

	-- Number keeps its white/outlined look but sizes to its own text (AutomaticSize)
	-- so the icon sits flush beside it; TextScaled is off (incompatible with auto-X).
	local num = RefSkin.label(box, numberText, {
		color = RefSkin.C.White,
		outline = o.outline or 2.5,
		textSize = ts,
		zindex = z,
		layoutOrder = 1,
	})
	num.TextScaled = false
	num.TextSize = ts
	num.AutomaticSize = Enum.AutomaticSize.X
	num.Size = UDim2.fromScale(0, 1)

	local ic = RefSkin.icon(box, currencyId, {
		size = UDim2.new(0, 0, 0.8, 0),
		zindex = z,
		layoutOrder = 2,
	})
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.DominantAxis = Enum.DominantAxis.Height
	ar.Parent = ic
end

-- ---- surface: image -> gradient -> border, crisp corners --------------
export type SurfaceCfg = {
	gradTop: Color3,
	gradBottom: Color3,
	border: Color3?,
	borderThick: number?,
	corner: number?,
	studTint: Color3?,
	studTransparency: number?, -- 0 = studs solid, 1 = no studs
	tile: number?,
}

-- Turns `frame` into a layered reference surface. Content the caller parents in
-- afterward renders ABOVE the image+gradient (they sit at ZIndex 0).
function RefSkin.surface(frame: GuiObject, cfg: SurfaceCfg)
	-- gradient BACKGROUND (frame white so the UIGradient shows the exact colours;
	-- fills the gaps between studs and is the fallback if the image can't load).
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	frame.BackgroundTransparency = 0
	frame.ClipsDescendants = true
	local fg = Instance.new("UIGradient")
	fg.Rotation = 90
	fg.Color = ColorSequence.new(cfg.gradTop, cfg.gradBottom)
	fg.Parent = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, cfg.corner or RefSkin.CORNER)
	corner.Parent = frame

	-- No studs on the modal body/header — studs are reserved for the Store's pack
	-- panel + its option cards (see RefExclusiveStore, which opts in via box studs).

	-- crisp BORDER.
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = cfg.border or RefSkin.C.Outline
	stroke.Thickness = cfg.borderThick or 2
	stroke.Parent = frame
end

-- THE core reference element: a gradient box nested inside a bordered box with a
-- thin gap, so outside-in you see: dark BORDER -> light BACKGROUND (the gap) ->
-- GRADIENT box -> content. Returns (outer, inner): parent content into `inner`;
-- `outer` is a TextButton when cfg.button, else a Frame.
export type BoxCfg = {
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	zindex: number?,
	lightBg: Color3?,
	border: Color3?,
	borderThick: number?,
	gap: number?,
	gradTop: Color3,
	gradBottom: Color3,
	studs: boolean?,
	button: boolean?,
	corner: number?,
}

function RefSkin.box(parent: Instance, cfg: BoxCfg): (GuiObject, Frame)
	local z = cfg.zindex or 2
	local corner = cfg.corner or RefSkin.CORNER

	local outer: GuiObject
	if cfg.button then
		local b = Instance.new("TextButton")
		b.Text = ""
		b.AutoButtonColor = true
		outer = b
	else
		outer = Instance.new("Frame")
	end
	outer.Name = "Box"
	outer.BorderSizePixel = 0
	-- The "gap" between the dark border and the gradient inner is a LIGHT TINT of
	-- THIS box's own colour (its gradTop lerped toward white), not a flat near-
	-- white — so every box reads as "a lighter shade of itself" showing through
	-- the gap. (cfg.lightBg is ignored now; the tint is derived per box.)
	outer.BackgroundColor3 = UIStyler.Lighten(cfg.gradTop, 0.6)
	if cfg.size then
		outer.Size = cfg.size
	end
	if cfg.position then
		outer.Position = cfg.position
	end
	if cfg.anchor then
		outer.AnchorPoint = cfg.anchor
	end
	outer.ZIndex = z
	local oc = Instance.new("UICorner")
	oc.CornerRadius = UDim.new(0, corner)
	oc.Parent = outer
	local os = Instance.new("UIStroke")
	os.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	os.Color = cfg.border or RefSkin.C.Outline
	os.Thickness = cfg.borderThick or 3
	os.Parent = outer
	outer.Parent = parent

	local gap = cfg.gap or 5
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BorderSizePixel = 0
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.new(1, -2 * gap, 1, -2 * gap)
	inner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	inner.ClipsDescendants = true
	inner.ZIndex = z + 1
	local ic = Instance.new("UICorner")
	ic.CornerRadius = UDim.new(0, corner)
	ic.Parent = inner
	local ig = Instance.new("UIGradient")
	ig.Rotation = 90
	ig.Color = ColorSequence.new(cfg.gradTop, cfg.gradBottom)
	ig.Parent = inner
	-- Studs are OPT-IN (cfg.studs = true) so only the surfaces that should carry
	-- them do — currently just the Store's pack panel + its option cards.
	if cfg.studs then
		local img = Instance.new("ImageLabel")
		img.Name = "Studs"
		img.BackgroundTransparency = 1
		img.Image = STUD
		-- Source stud image is ~3:1 (wide) and a full studded panel, so tile BIG
		-- and at 3:1 — a small/square tile squishes studs into bars or gray mush.
		img.ScaleType = Enum.ScaleType.Tile
		img.TileSize = UDim2.fromOffset(600, 200)
		img.ImageColor3 = Color3.fromRGB(255, 255, 255)
		img.ImageTransparency = 0.5
		img.Size = UDim2.fromScale(1, 1)
		img.ZIndex = 1
		img.Parent = inner
	end
	inner.Parent = outer
	return outer, inner
end

-- A vertical ScrollingFrame with a visible scrollbar and an EXPLICIT CanvasSize
-- (canvasFactor > 1 = taller than the viewport, so it scrolls). Content is
-- positioned with Scale where 1.0 == one viewport height; place items past 1.0
-- to fill the scroll region. Explicit CanvasSize avoids the AutomaticCanvasSize
-- collapse. Returns the ScrollingFrame to parent content into.
function RefSkin.scroll(parent: Instance, canvasFactor: number): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.Name = "Scroll"
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Size = UDim2.fromScale(1, 1)
	s.CanvasSize = UDim2.fromScale(0, canvasFactor)
	s.ScrollBarThickness = 12
	s.ScrollBarImageColor3 = RefSkin.C.Scroll
	s.ScrollBarImageTransparency = 0
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.ZIndex = 3
	s.Parent = parent
	return s
end

-- Plain 2-colour vertical gradient fill (no studs) for small elements — buttons,
-- bar fills, art boxes. Sets the frame white so the gradient shows exact colours.
function RefSkin.gradientFill(frame: GuiObject, top: Color3, bottom: Color3): UIGradient
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = frame
	return g
end

-- Back-compat alias (RefHUD uses the old name).
RefSkin.fillGradient = RefSkin.gradientFill

-- ---- text helpers -----------------------------------------------------

function RefSkin.outline(obj: GuiObject, color: Color3?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Color = color or RefSkin.C.Outline
	s.Thickness = thickness or 2.5
	s.Parent = obj
	return s
end

export type LabelOpts = {
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	align: Enum.TextXAlignment?,
	textSize: number?,
	outline: number?,
	zindex: number?,
	layoutOrder: number?,
}

function RefSkin.label(parent: Instance, text: string, opts: LabelOpts?): TextLabel
	local o = opts or {}
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.RichText = true
	l.Text = text
	l.FontFace = RefSkin.Font
	l.TextColor3 = o.color or RefSkin.C.White
	l.TextXAlignment = o.align or Enum.TextXAlignment.Center
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextScaled = true
	l.Size = o.size or UDim2.fromScale(1, 1)
	if o.position then
		l.Position = o.position
	end
	if o.anchor then
		l.AnchorPoint = o.anchor
	end
	l.ZIndex = o.zindex or 5
	if o.layoutOrder then
		l.LayoutOrder = o.layoutOrder
	end
	l.Parent = parent
	if (o.outline or 2.5) > 0 then
		RefSkin.outline(l, RefSkin.C.Outline, o.outline)
	end
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = o.textSize or 40
	c.MinTextSize = 6
	c.Parent = l
	return l
end

-- A rounded pill/chip (crisp corner + border).
function RefSkin.pill(parent: Instance, size: UDim2, fill: Color3, border: Color3?): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.BorderSizePixel = 0
	f.BackgroundColor3 = fill
	f.ZIndex = 4
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, RefSkin.CORNER)
	c.Parent = f
	RefSkin.outline(f, border or RefSkin.C.Outline, 2.5)
	f.Parent = parent
	return f
end

-- ---- shared modal shell -----------------------------------------------
export type Modal = { root: GuiObject, header: Frame, body: Frame, close: TextButton }

export type ModalOpts = {
	parent: Instance,
	title: string,
	icon: string?,
	iconId: string?, -- image asset id for the title icon (preferred over `icon`)
	aspect: number,
	widthScale: number,
	dark: boolean?,
	transparency: number?, -- 0 = opaque, >0 = whole panel translucent (Settings)
	onClose: (() -> ())?,
}

function RefSkin.Modal(opts: ModalOpts): Modal
	local C = RefSkin.C
	local dark = opts.dark == true

	-- A CanvasGroup lets the WHOLE panel go uniformly translucent (Settings) via
	-- GroupTransparency; opaque panels use it at 0 (no visual change).
	local root: GuiObject
	if opts.transparency and opts.transparency > 0 then
		local cg = Instance.new("CanvasGroup")
		cg.GroupTransparency = opts.transparency
		root = cg
	else
		root = Instance.new("Frame")
	end
	root.Name = "Modal"
	root.BorderSizePixel = 0
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(opts.widthScale, 0.9)
	root.ClipsDescendants = true
	root.Parent = opts.parent
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = opts.aspect
	ratio.DominantAxis = Enum.DominantAxis.Width
	ratio.Parent = root
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, RefSkin.CORNER)
	rc.Parent = root
	local rs = Instance.new("UIStroke")
	rs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rs.Color = dark and C.SetHeaderBottom or C.ModalBorder
	rs.Thickness = 4
	rs.Parent = root

	-- Body (fills; header overlaps its top). Content parents into `body`.
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BorderSizePixel = 0
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.fromScale(0.5, 1)
	body.Size = UDim2.fromScale(1, 0.84)
	body.ZIndex = 2
	RefSkin.surface(body, {
		gradTop = dark and C.SetBodyTop or C.BodyTop,
		gradBottom = dark and C.SetBodyBottom or C.BodyBottom,
		border = dark and C.SetHeaderBottom or C.FeaturedBorder,
		borderThick = 0,
		corner = 0,
		studTransparency = 0.25,
	})
	body.Parent = root

	-- Header.
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0.16, 0)
	header.ZIndex = 3
	RefSkin.surface(header, {
		gradTop = dark and C.SetHeaderTop or C.TitleTop,
		gradBottom = dark and C.SetHeaderBottom or C.TitleBottom,
		border = dark and C.SetHeaderBottom or C.HeaderBorder,
		borderThick = 0,
		corner = 0,
		studTransparency = 0.2,
	})
	header.Parent = root

	if opts.iconId then
		RefSkin.icon(header, opts.iconId, {
			size = UDim2.fromScale(0.085, 0.66),
			position = UDim2.fromScale(0.025, 0.5),
			anchor = Vector2.new(0, 0.5),
			zindex = 4,
		})
	elseif opts.icon then
		RefSkin.label(header, opts.icon, {
			size = UDim2.fromScale(0.11, 0.66),
			position = UDim2.fromScale(0.02, 0.5),
			anchor = Vector2.new(0, 0.5),
			outline = 0,
			zindex = 4,
		})
	end
	RefSkin.label(header, opts.title, {
		size = UDim2.fromScale(0.72, 0.6),
		position = UDim2.fromScale((opts.icon or opts.iconId) and 0.15 or 0.04, 0.5),
		anchor = Vector2.new(0, 0.5),
		align = Enum.TextXAlignment.Left,
		color = C.White,
		outline = 3,
		zindex = 4,
	})

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.fromScale(0.985, 0.5)
	close.Size = UDim2.fromScale(0.09, 0.72)
	close.BackgroundColor3 = C.Red
	close.AutoButtonColor = true
	close.Text = ""
	close.ZIndex = 4
	local car = Instance.new("UIAspectRatioConstraint")
	car.AspectRatio = 1
	car.Parent = close
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, RefSkin.CORNER)
	cc.Parent = close
	RefSkin.outline(close, C.RedDark, 3)
	-- Draw the X from two rotated bars — the ✕ glyph doesn't render in the
	-- FredokaOne display font (no glyph fallback), which left the button empty.
	for _, rot in { 45, -45 } do
		local bar = Instance.new("Frame")
		bar.Name = "XBar"
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromScale(0.64, 0.18)
		bar.BackgroundColor3 = C.White
		bar.BorderSizePixel = 0
		bar.Rotation = rot
		bar.ZIndex = 5
		local bcorner = Instance.new("UICorner")
		bcorner.CornerRadius = UDim.new(1, 0)
		bcorner.Parent = bar
		bar.Parent = close
	end
	close.Parent = header
	if opts.onClose then
		close.Activated:Connect(opts.onClose)
	end

	return { root = root, header = header, body = body, close = close }
end

return RefSkin

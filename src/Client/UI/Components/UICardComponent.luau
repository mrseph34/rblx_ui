--!strict
-- Spec-driven shop entry renderer. ONE renderer builds every card; the active
-- pack's EntrySpec decides the arrangement (image-focal, list row, split,
-- text-heavy, banner). Consistency is structural: the individual elements
-- (image swatch, name, description, price, tag pills, buy button) are built by
-- shared _Make* helpers and themed in one _Style, so every entry in a pack is
-- identical in construction and a theme always paints them the same. Only
-- placement changes between packs — never the elements themselves.
--
-- Props:
--   item         : Shared.Types.ShopItem (required)
--   spec         : EntryLayoutConfig.EntrySpec (defaults to StandardCard)
--   currencyIcon : emoji for the price chip
--   affordable, owned : booleans
--   onBuy        : (item) -> ()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedTypes = require(ReplicatedStorage.Shared.Types)
local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local ThemeShape = require(script.Parent.Parent.ThemeShape)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local EntryLayoutConfig = require(script.Parent.Parent.Config.EntryLayoutConfig)
local UIComponentBase = require(script.Parent.UIComponentBase)
local UIButtonComponent = require(script.Parent.UIButtonComponent)
local UIBadgeComponent = require(script.Parent.UIBadgeComponent)

local UICardComponent = setmetatable({}, { __index = UIComponentBase })
UICardComponent.__index = UICardComponent

function UICardComponent.new()
	local self = UIComponentBase.new("UICard")
	self._badges = {}
	return setmetatable(self, UICardComponent)
end

-- Deterministic pastel from the item id — a stable, distinct placeholder swatch
-- per item until real icon art (item.iconId) replaces it.
local function monogramColor(id: string): Color3
	local hash = 0
	for i = 1, #id do
		hash = (hash * 31 + string.byte(id, i)) % 360
	end
	return Color3.fromHSV(hash / 360, 0.5, 0.85)
end

function UICardComponent:_Build(props: Types.UIComponentProps)
	local item = props.item :: SharedTypes.ShopItem
	local spec = (props.spec :: EntryLayoutConfig.EntrySpec?) or EntryLayoutConfig.Get("StandardCard")
	self._spec = spec
	self._item = item

	local root = self.Root
	root.BackgroundTransparency = 1

	-- Drop shadow behind the card (Raised3D only; hidden otherwise).
	local shadow = UIStyler.DropShadow(5, 1)
	shadow.Parent = root
	self._shadow = shadow

	-- Surface = fixed footprint's visual layer; hover/press scale this, not the
	-- Root, so cards never spill into neighbours or reflow the grid/list.
	local surface = UIStyler.Frame("Surface")
	surface.BackgroundTransparency = 0
	surface.Size = UDim2.fromScale(1, 1)
	surface.AnchorPoint = Vector2.new(0.5, 0.5)
	surface.Position = UDim2.fromScale(0.5, 0.5)
	surface.ClipsDescendants = true
	surface.ZIndex = 2
	surface.Parent = root
	self._surface = surface
	self:_UseScaleTarget(surface)

	self._corner = UIStyler.Corner(16)
	self._corner.Parent = surface
	self._stroke = UIStyler.Stroke(Color3.new(), 1.5)
	self._stroke.Parent = surface
	self._gradient = UIStyler.Gradient(90, 0.1)
	self._gradient.Parent = surface

	-- Inner bevel overlay for Raised3D (ZIndex 1 so arrangement content, added at
	-- default ZIndex within the surface, still reads above it).
	local bevel = UIStyler.Bevel(1, 0)
	bevel.ZIndex = 1
	bevel.Visible = false
	bevel.Parent = surface
	self._bevel = bevel

	-- Dispatch to the arrangement. Each lays out shared elements differently.
	local arrangement = spec.arrangement
	if arrangement == "Row" then
		self:_BuildRow(surface, spec)
	elseif arrangement == "Split" then
		self:_BuildSplit(surface, spec, 0.5)
	elseif arrangement == "Banner" then
		self:_BuildSplit(surface, spec, 0.6)
	elseif arrangement == "TextFirst" then
		self:_BuildTextFirst(surface, spec)
	elseif arrangement == "Overlay" then
		self:_BuildOverlay(surface, spec)
	else
		self:_BuildCardTop(surface, spec)
	end
end

-- ========================================================================
-- Shared element builders — used by every arrangement (this is what keeps
-- entries consistent no matter the pack).
-- ========================================================================

function UICardComponent:_MakeImage(parent: Instance, size: UDim2, fillWidth: boolean?): Frame
	local item = self._item
	local holder = UIStyler.Frame("Image")
	holder.Size = size
	holder.BackgroundColor3 = monogramColor(item.id)
	self._imageHolder = holder
	self._imageCorner = UIStyler.Corner(12)
	self._imageCorner.Parent = holder

	-- Aspect ratio, applied ONLY where the image has a square-ish footprint we
	-- must protect from stretching — the Row/TextFirst offset thumbnails and the
	-- Split image column. CardTop images deliberately FILL the full card width
	-- (a hero banner) and are sized by height alone, so they never leave the ugly
	-- empty gap beside a shrunken square. `fillWidth` opts a caller out entirely.
	local aspect = (self._spec :: any).imageAspect
	if not fillWidth and aspect and aspect > 0 then
		-- The concrete axis stays authoritative; the free axis is computed to hold
		-- the ratio. Width concrete (scaled or offset) -> Width dominant; otherwise
		-- height is concrete (a fixed-height slot) -> Height dominant.
		local widthConcrete = size.X.Scale ~= 0 or size.X.Offset ~= 0
		local dominant = widthConcrete and Enum.DominantAxis.Width or Enum.DominantAxis.Height
		UIStyler.AspectRatio(aspect, dominant).Parent = holder
	end

	if item.iconId ~= "" then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Image = item.iconId
		image.Parent = holder
	else
		local mono = UIStyler.TextLabel("Mono")
		mono.Size = UDim2.fromScale(1, 1)
		mono.TextScaled = true
		mono.Text = string.upper(string.sub(TextConfig.Resolve(item.nameKey), 1, 1))
		mono.TextColor3 = Color3.new(1, 1, 1)
		UIStyler.Padding(math.max(8, math.floor(holder.Size.Y.Offset * 0.18))).Parent = mono
		mono.Parent = holder
	end
	holder.Parent = parent
	return holder
end

function UICardComponent:_MakeName(parent: Instance, height: number): TextLabel
	local name = UIStyler.TextLabel("Name")
	name.Size = UDim2.new(1, 0, 0, height)
	name.TextXAlignment = self._spec.nameAlign
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = TextConfig.Resolve(self._item.nameKey)
	name.Parent = parent
	self._name = name
	return name
end

function UICardComponent:_MakeDescription(parent: Instance): TextLabel?
	if not self._spec.showDescription then
		return nil
	end
	local desc = UIStyler.TextLabel("Description")
	desc.Size = UDim2.new(1, 0, 1, 0)
	desc.AutomaticSize = Enum.AutomaticSize.None
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextWrapped = true
	desc.Text = self._item.descriptionKey and TextConfig.Resolve(self._item.descriptionKey) or ""
	desc.Parent = parent
	self._desc = desc
	return desc
end

function UICardComponent:_MakePrice(parent: Instance): TextLabel
	local price = UIStyler.TextLabel("Price")
	price.Size = UDim2.new(1, 0, 0, 20)
	price.TextXAlignment = self._spec.nameAlign
	price.Text = string.format("%s %s", self.Props.currencyIcon or "", tostring(self._item.price))
	price.Parent = parent
	self._price = price
	return price
end

-- Always returns a fixed-height row when the spec shows tags — even for an item
-- with no tags — so the slot is reserved and every card in a pack keeps the
-- same vertical rhythm (an item missing tags must not shift name/price/buy).
-- Returns nil only when the pack doesn't use tags at all.
function UICardComponent:_MakeTags(parent: Instance): Frame?
	if not self._spec.showTags then
		return nil
	end
	local item = self._item
	local tagRow = UIStyler.Frame("Tags")
	tagRow.BackgroundTransparency = 1
	tagRow.Size = UDim2.new(1, 0, 0, 18)
	UIStyler.ListLayout({
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = self._spec.nameAlign == Enum.TextXAlignment.Center
			and Enum.HorizontalAlignment.Center
			or Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 4),
	}).Parent = tagRow
	tagRow.Parent = parent
	if item.tags then
		for i, tag in item.tags do
			local badge = UIBadgeComponent.new()
			badge:Create(tagRow, { text = tag, variant = tag, layoutOrder = i })
			table.insert(self._badges, badge)
		end
	end
	return tagRow
end

function UICardComponent:_MakeBuy(parent: Instance): GuiObject
	local props = self.Props
	local spec = self._spec
	local buy = UIButtonComponent.new()
	self._buy = buy
	local size
	if spec.buyStyle == "Compact" then
		size = UDim2.new(0, 92, 0, 34)
	elseif spec.buyStyle == "IconRight" then
		size = UDim2.new(0, 40, 0, 34)
	else
		size = UDim2.new(1, 0, 0, 38)
	end
	buy:Create(parent, {
		textKey = props.owned and "shop.owned" or "shop.buy",
		variant = props.owned and "Ghost" or (props.affordable ~= false and "Success" or "Ghost"),
		enabled = not props.owned and props.affordable ~= false,
		size = size,
		onClick = function()
			if props.onBuy then
				props.onBuy(self._item)
			end
			self:PlayAnimation("Pulse")
		end,
	})
	return buy.Root
end

-- Small helper: a transparent vertical stack container.
local function stack(name: string, padding: number, align: Enum.HorizontalAlignment?): Frame
	local frame = UIStyler.Frame(name)
	frame.BackgroundTransparency = 1
	UIStyler.ListLayout({
		Padding = UDim.new(0, padding),
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	}).Parent = frame
	return frame
end

-- ========================================================================
-- Arrangements
-- ========================================================================

-- Image on top, text stacked below. Standard grid card / image-focal.
function UICardComponent:_BuildCardTop(surface: Frame, spec: EntryLayoutConfig.EntrySpec)
	UIStyler.Padding(10).Parent = surface
	local col = stack("Content", 6, spec.nameAlign == Enum.TextXAlignment.Center and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left)
	col.Size = UDim2.fromScale(1, 1)
	col.Parent = surface

	local order = 0
	local function next_(o: GuiObject)
		order += 1
		o.LayoutOrder = order
	end
	-- Image is a CENTRED square (or spec aspect) whose size ShopScreen computed to
	-- keep the whole card compact & roughly square (AAA tiles, not long strips).
	-- imageSizePx = the square's SIDE (width); height = side / aspect. It's centred
	-- in a full-width row, so on wide cards there are small even margins — never a
	-- lonely square hugging one edge, never a lanky card.
	local aspect = (spec :: any).imageAspect
	if not aspect or aspect <= 0 then
		aspect = 1 -- square default
	end
	local imgW = (self.Props :: any).imageSizePx or (spec.imageHeight or 120)
	local imgH = math.ceil(imgW / aspect)
	local wrap = UIStyler.Frame("ImageWrap")
	wrap.BackgroundTransparency = 1
	wrap.Size = UDim2.new(1, 0, 0, imgH)
	wrap.Parent = col
	next_(wrap)
	local img = self:_MakeImage(wrap, UDim2.fromOffset(imgW, imgH), true)
	img.AnchorPoint = Vector2.new(0.5, 0)
	img.Position = UDim2.fromScale(0.5, 0)
	local tags = self:_MakeTags(col)
	if tags then
		next_(tags)
	end
	next_(self:_MakeName(col, 22))
	local price = self:_MakePrice(col)
	next_(price)
	-- Spacer pushes buy to the bottom.
	local spacer = UIStyler.Frame("Spacer")
	spacer.BackgroundTransparency = 1
	spacer.Size = UDim2.new(1, 0, 0, 0)
	spacer.LayoutOrder = 900
	spacer.Parent = col
	local layout = col:FindFirstChildOfClass("UIListLayout")
	if layout then
		spacer.Size = UDim2.new(1, 0, 0, 2)
	end
	local buy = self:_MakeBuy(col)
	buy.LayoutOrder = 999
end

-- Full-bleed image with the text OVERLAID on it (name/price/tags/buy), over a
-- dark bottom scrim so the text is readable over any art. The whole card is the
-- image — no text block below — so it's compact (card == image square) and looks
-- premium. Tags sit top-left, name+price bottom-left over the scrim, buy bottom.
function UICardComponent:_BuildOverlay(surface: Frame, spec: EntryLayoutConfig.EntrySpec)
	-- Image fills the entire card.
	local img = self:_MakeImage(surface, UDim2.fromScale(1, 1), true)
	img.ZIndex = 2

	-- Bottom scrim: a dark gradient fading from transparent (top) to opaque
	-- (bottom) so overlaid text reads over bright art without hiding the image.
	local scrim = UIStyler.Frame("Scrim")
	scrim.BackgroundColor3 = Color3.new(0, 0, 0)
	scrim.BackgroundTransparency = 0
	scrim.AnchorPoint = Vector2.new(0.5, 1)
	scrim.Position = UDim2.fromScale(0.5, 1)
	scrim.Size = UDim2.new(1, 0, 0.55, 0)
	scrim.ZIndex = 3
	local scrimGrad = Instance.new("UIGradient")
	scrimGrad.Rotation = 90
	scrimGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	scrimGrad.Parent = scrim
	scrim.Parent = surface
	self._scrim = scrim
	-- Match the card corner so the scrim doesn't poke past rounded edges.
	local scrimCorner = UIStyler.Corner(16)
	scrimCorner.Parent = scrim
	self._scrimCorner = scrimCorner

	-- Tags top-left over the image.
	if spec.showTags then
		local tags = self:_MakeTags(surface)
		if tags then
			tags.AnchorPoint = Vector2.new(0, 0)
			tags.Position = UDim2.fromOffset(10, 10)
			tags.Size = UDim2.new(1, -20, 0, 22)
			tags.ZIndex = 6
			for _, d in tags:GetDescendants() do
				if d:IsA("GuiObject") then
					d.ZIndex = 6
				end
			end
		end
	end

	-- Text column pinned to the bottom over the scrim. Name + price stack, and a
	-- compact Buy sits to the right so nothing overflows the card's bottom edge.
	local info = UIStyler.Frame("Info")
	info.BackgroundTransparency = 1
	info.AnchorPoint = Vector2.new(0, 1)
	info.Position = UDim2.new(0, 10, 1, -10)
	info.Size = UDim2.new(1, -20, 0, 44)
	info.ZIndex = 5
	info.Parent = surface

	local name = self:_MakeName(info, 20)
	name.Size = UDim2.new(1, -70, 0, 20)
	name.Position = UDim2.fromOffset(0, 0)
	name.ZIndex = 5
	local price = self:_MakePrice(info)
	price.Size = UDim2.new(1, -70, 0, 20)
	price.Position = UDim2.fromOffset(0, 22)
	price.ZIndex = 5
	-- Compact Buy button, right-aligned, vertically centred over the two text rows.
	local buy = self:_MakeBuy(info)
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, 0, 0.5, 0)
	buy.Size = UDim2.fromOffset(60, 34)
	for _, d in buy:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = math.max(d.ZIndex, 5)
		end
	end
	buy.ZIndex = 5
end

-- Small image left · name+tags middle · price+buy right. List / compact row.
function UICardComponent:_BuildRow(surface: Frame, spec: EntryLayoutConfig.EntrySpec)
	UIStyler.PaddingXY(10, 8).Parent = surface
	local row = UIStyler.Frame("Content")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	UIStyler.ListLayout({
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
	}).Parent = row
	row.Parent = surface

	local imageSize = spec.imageSize or 52
	local img = self:_MakeImage(row, UDim2.fromOffset(imageSize, imageSize))
	img.LayoutOrder = 1

	local middle = stack("Middle", 3)
	middle.Size = UDim2.new(1, -(imageSize + 10 + 140), 1, 0)
	middle.LayoutOrder = 2
	middle.Parent = row
	self:_MakeName(middle, 22).LayoutOrder = 1
	local tags = self:_MakeTags(middle)
	if tags then
		tags.LayoutOrder = 2
	end

	local right = stack("Right", 4, Enum.HorizontalAlignment.Right)
	right.Size = UDim2.new(0, 130, 1, 0)
	right.LayoutOrder = 3
	right.Parent = row
	local price = self:_MakePrice(right)
	price.Size = UDim2.new(1, 0, 0, 20)
	price.TextXAlignment = Enum.TextXAlignment.Right
	price.LayoutOrder = 1
	local buy = self:_MakeBuy(right)
	buy.LayoutOrder = 2
end

-- Large image left, text column right (name, desc, tags, price, buy). Split.
function UICardComponent:_BuildSplit(surface: Frame, spec: EntryLayoutConfig.EntrySpec, _variant: number)
	UIStyler.Padding(10).Parent = surface
	local row = UIStyler.Frame("Content")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	UIStyler.ListLayout({
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, 12),
	}).Parent = row
	row.Parent = surface

	local imageW = spec.imageWidth or 0.4
	local img = self:_MakeImage(row, UDim2.new(imageW, -6, 1, 0))
	-- mirror = image on the right, text on the left (SplitRight spec).
	img.LayoutOrder = spec.mirror and 2 or 1

	local right = stack("Right", 6)
	right.Size = UDim2.new(1 - imageW, -6, 1, 0)
	right.LayoutOrder = spec.mirror and 1 or 2
	right.Parent = row
	local o = 0
	local function next_(g: GuiObject) o += 1; g.LayoutOrder = o end
	next_(self:_MakeName(right, 24))
	local tags = self:_MakeTags(right)
	if tags then next_(tags) end
	local desc = self:_MakeDescription(right)
	if desc then
		desc.Size = UDim2.new(1, 0, 0, 44)
		next_(desc)
	end
	next_(self:_MakePrice(right))
	local spacer = UIStyler.Frame("Spacer"); spacer.BackgroundTransparency = 1; spacer.Size = UDim2.new(1,0,0,2); spacer.Parent = right; next_(spacer)
	local buy = self:_MakeBuy(right); buy.LayoutOrder = 999
end

-- Name + description hero, small image top-right, price+buy footer. Text-heavy.
function UICardComponent:_BuildTextFirst(surface: Frame, spec: EntryLayoutConfig.EntrySpec)
	UIStyler.Padding(12).Parent = surface
	local col = stack("Content", 6)
	col.Size = UDim2.fromScale(1, 1)
	col.Parent = surface

	-- Header: name (left, fills) + small square image (right).
	local header = UIStyler.Frame("Header")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, spec.imageSize or 44)
	header.LayoutOrder = 1
	header.Parent = col
	local imgSize = spec.imageSize or 44
	local img = self:_MakeImage(header, UDim2.fromOffset(imgSize, imgSize))
	img.AnchorPoint = Vector2.new(1, 0)
	img.Position = UDim2.fromScale(1, 0)
	local name = self:_MakeName(header, imgSize)
	name.Size = UDim2.new(1, -(imgSize + 10), 1, 0)
	name.TextYAlignment = Enum.TextYAlignment.Center

	local tags = self:_MakeTags(col)
	if tags then tags.LayoutOrder = 2 end
	local desc = self:_MakeDescription(col)
	if desc then
		desc.Size = UDim2.new(1, 0, 0, 46)
		desc.LayoutOrder = 3
	end

	-- Footer: price left, buy right.
	local footer = UIStyler.Frame("Footer")
	footer.BackgroundTransparency = 1
	footer.Size = UDim2.new(1, 0, 0, 40)
	footer.LayoutOrder = 999
	footer.Parent = col
	local price = self:_MakePrice(footer)
	price.Size = UDim2.new(0.5, 0, 1, 0)
	price.TextYAlignment = Enum.TextYAlignment.Center
	local buy = self:_MakeBuy(footer)
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, 0, 0.5, 0)
	buy.Size = UDim2.new(0, 130, 0, 36)
end

-- ========================================================================
-- Theming (one place → consistent across all arrangements)
-- ========================================================================

function UICardComponent:_Style(theme: Types.UITheme)
	local c = theme.Colors
	local shape = ThemeShape.Resolve(theme)
	self:_SetColor(self._surface, "BackgroundColor3", c.SurfaceRaised)
	local radius = ThemeShape.Radius(theme, theme.Radii.Large)
	self._corner.CornerRadius = UDim.new(0, radius)
	if self._imageCorner then
		self._imageCorner.CornerRadius = UDim.new(0, ThemeShape.Radius(theme, theme.Radii.Medium))
	end
	self._stroke.Color = c.Stroke
	self._stroke.Thickness = theme.Effects.StrokeThickness
	self._stroke.Transparency = 0.35
	self._gradient.Enabled = theme.Effects.UseGradients
	self._gradient.Color = UIStyler.Gradient(90, theme.Effects.GradientIntensity).Color

	-- Raised3D: bevel inside + drop shadow behind so cards read extruded too.
	local raised = shape.Style == "Raised3D"
	self._bevel.Visible = raised
	if raised then
		local ownGrad = self._bevel:FindFirstChildOfClass("UIGradient")
		local ref = UIStyler.Bevel(shape.HighlightTransparency, shape.ShadowStrength)
		local refGrad = ref:FindFirstChildOfClass("UIGradient")
		if ownGrad and refGrad then
			ownGrad.Transparency = refGrad.Transparency
		end
		ref:Destroy()
		local bevelCorner = self._bevel:FindFirstChildOfClass("UICorner") or UIStyler.Corner(radius)
		bevelCorner.CornerRadius = UDim.new(0, radius)
		bevelCorner.Parent = self._bevel
	end
	self._shadow.ImageTransparency = raised and math.clamp(1 - shape.ShadowStrength * 0.8, 0, 1) or 1

	-- Overlay cards put text over the image, so name/price are forced WHITE (over
	-- the dark bottom scrim) for readability regardless of the theme's text colour.
	local overlay = self._spec.arrangement == "Overlay"
	self._name.FontFace = theme.Fonts.Subtitle
	self._name.TextSize = theme.TextSizes.Subtitle
	self._name.TextColor3 = overlay and Color3.new(1, 1, 1) or c.TextPrimary

	self._price.FontFace = theme.Fonts.Numeric
	self._price.TextSize = theme.TextSizes.Body
	self._price.TextColor3 = c.Accent

	if self._desc then
		self._desc.FontFace = theme.Fonts.Body
		self._desc.TextSize = theme.TextSizes.Small
		self._desc.TextColor3 = c.TextSecondary
	end

	-- Overlay scrim: keep its rounded corner matched so it fits the card.
	if self._scrimCorner then
		self._scrimCorner.CornerRadius = UDim.new(0, radius)
	end
end

function UICardComponent:Destroy()
	for _, badge in self._badges do
		badge:Destroy()
	end
	if self._buy then
		self._buy:Destroy()
	end
	UIComponentBase.Destroy(self)
end

return UICardComponent

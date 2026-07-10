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

	-- Drop shadow behind the card (Raised3D only; hidden otherwise). Cards tile
	-- with only ~10px between them, so this uses a SMALL bleed (growPx=8,
	-- offsetY=2) that fades out safely inside that gap — a bigger bleed gets
	-- sliced off by the neighbouring card's opaque surface, which looks like a
	-- broken hard cutoff instead of a soft shadow.
	local shadow = UIStyler.DropShadow(2, 1, 8)
	shadow.Parent = root
	self._shadow = shadow

	-- "OutsideBelow"/"Straddle" buy styles put the button OUTSIDE the card's
	-- clipped surface — floating fully or partly below its rounded bottom edge.
	-- For those, shrink the surface to leave room at the bottom of Root and
	-- top-anchor it there; the real button is built as a Root-level sibling
	-- AFTER the arrangement runs (see the bottom of this function), so it is
	-- never clipped by the surface's ClipsDescendants.
	local externalBuy = spec.arrangement == "CardTop"
		and (spec.buyStyle == "OutsideBelow" or spec.buyStyle == "Straddle")
	-- OutsideBelow reserves a full button + gap; Straddle only reserves HALF a
	-- button's height (the other half overlaps the surface on top of it).
	local externalReserve = externalBuy and (spec.buyStyle == "Straddle" and 20 or 48) or 0
	self._externalReserve = externalReserve

	-- Surface = fixed footprint's visual layer; hover/press scale this, not the
	-- Root, so cards never spill into neighbours or reflow the grid/list.
	local surface = UIStyler.Frame("Surface")
	surface.BackgroundTransparency = 0
	if externalBuy then
		surface.Size = UDim2.new(1, 0, 1, -externalReserve)
		surface.AnchorPoint = Vector2.new(0.5, 0)
		surface.Position = UDim2.new(0.5, 0, 0, 0)
	else
		surface.Size = UDim2.fromScale(1, 1)
		surface.AnchorPoint = Vector2.new(0.5, 0.5)
		surface.Position = UDim2.fromScale(0.5, 0.5)
	end
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

	if externalBuy then
		self:_BuildExternalBuy(root, spec)
	end
end

-- Builds the real buy button as a Root-level SIBLING of the (clipped) surface,
-- so it is never cut off by ClipsDescendants — used by "OutsideBelow" (fully
-- below the box, not touching it) and "Straddle" (centred ON the box's bottom
-- edge, half overlapping inside, half hanging out below).
function UICardComponent:_BuildExternalBuy(root: Frame, spec: EntryLayoutConfig.EntrySpec)
	local props = self.Props
	local buy = UIButtonComponent.new()
	self._buy = buy
	local straddle = spec.buyStyle == "Straddle"
	-- Default: as wide as the box itself (matches the card, edge to edge) — a
	-- per-spec buttonSize can override this later if a narrower/fixed width is
	-- ever wanted, but the out-of-the-box default spans the full card width.
	local buttonH = straddle and 40 or 38
	local size = UDim2.new(1, 0, 0, buttonH)
	buy:Create(root, {
		textKey = props.owned and "shop.owned" or "shop.buy",
		variant = props.owned and "Ghost" or (props.affordable ~= false and "Success" or "Ghost"),
		enabled = not props.owned and props.affordable ~= false,
		size = size,
		anchorPoint = Vector2.new(0.5, straddle and 0.5 or 1),
		-- Straddle: centred exactly on the surface's bottom edge (root height
		-- minus the half-button reserve). OutsideBelow: flush with Root's own
		-- bottom edge, safely inside the full-button-plus-gap reserve.
		position = straddle and UDim2.new(0.5, 0, 1, -self._externalReserve) or UDim2.new(0.5, 0, 1, 0),
		onClick = function()
			if props.onBuy then
				props.onBuy(self._item)
			end
			self:PlayAnimation("Pulse")
		end,
	})
	-- Sits above the surface so the overlapping half of a Straddle button reads
	-- as "on top of" the box, not tucked behind it.
	buy.Root.ZIndex = 6
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
	-- Quantity: an inventory view has nothing to purchase — show an owned-count
	-- badge in the same slot instead of a buy button.
	if spec.buyStyle == "Quantity" then
		return self:_MakeQuantityBadge(parent)
	end
	local buy = UIButtonComponent.new()
	self._buy = buy
	local size
	if spec.buyStyle == "Compact" then
		size = UDim2.new(0, 92, 0, 34)
	elseif spec.buyStyle == "IconRight" then
		size = UDim2.new(0, 40, 0, 34)
	elseif spec.buyStyle == "Pill" then
		-- Smaller, rounder, centred — deliberately NOT flush with the image box
		-- above it (the caller adds real spacing before this).
		size = UDim2.new(0, 116, 0, 32)
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
	if spec.buyStyle == "Pill" then
		-- Pill buttons are always fully round regardless of the theme's roundness.
		local corner = buy.Root:FindFirstChild("Surface") and buy.Root.Surface:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(1, 0)
		end
	end
	return buy.Root
end

-- Themed "×N owned" chip for inventory-style rows (QuantityRow / buyStyle
-- "Quantity"). Not a button — nothing to purchase here, just what's owned.
-- Quantity is deterministic per item (stable across re-renders) unless the game
-- supplies a real one via props.quantity.
function UICardComponent:_MakeQuantityBadge(parent: Instance): Frame
	local chip = UIStyler.Frame("Quantity")
	chip.Size = UDim2.fromOffset(0, 30)
	chip.AutomaticSize = Enum.AutomaticSize.X
	self._qtyCorner = UIStyler.Corner(1000)
	self._qtyCorner.Parent = chip
	UIStyler.PaddingXY(12, 4).Parent = chip
	local label = UIStyler.TextLabel("Count")
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.Parent = chip
	self._qtyLabel = label
	chip.Parent = parent

	local quantity = (self.Props :: any).quantity
	if not quantity then
		-- Stable per-item fallback so the same item always shows the same count.
		local hash = 0
		for i = 1, #self._item.id do
			hash = (hash * 31 + string.byte(self._item.id, i)) % 12
		end
		quantity = hash + 1
	end
	label.Text = "×" .. tostring(quantity)
	return chip
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
	-- "OutsideBelow"/"Straddle": the real button is built externally (see
	-- _Build/_BuildExternalBuy) as a sibling of the surface, so it's never
	-- clipped — just close out the column with a little bottom padding here so
	-- price doesn't touch the surface's clipped edge.
	if spec.buyStyle == "OutsideBelow" or spec.buyStyle == "Straddle" then
		local pad = UIStyler.Frame("BottomPad")
		pad.BackgroundTransparency = 1
		pad.Size = UDim2.new(1, 0, 0, 4)
		pad.LayoutOrder = 900
		pad.Parent = col
		return
	end
	-- Spacer pushes buy to the bottom.
	local spacer = UIStyler.Frame("Spacer")
	spacer.BackgroundTransparency = 1
	spacer.Size = UDim2.new(1, 0, 0, 0)
	spacer.LayoutOrder = 900
	spacer.Parent = col
	local layout = col:FindFirstChildOfClass("UIListLayout")
	if layout then
		-- Pill buttons get real breathing room so they read as a separate element
		-- below the image box, not flush against the price row like a normal buy.
		spacer.Size = UDim2.new(1, 0, 0, spec.buyStyle == "Pill" and 12 or 2)
	end
	local buy = self:_MakeBuy(col)
	buy.LayoutOrder = 999
	-- (Pill buttons are meant for a CENTRED spec — nameAlign = Center — so the
	-- column's own HorizontalAlignment already centres a narrower button like this.)
end

-- Full-bleed image with the text OVERLAID on it (name/price/tags/buy). Two
-- readability treatments, picked by spec.overlayBg:
--   "Scrim" (default) — a dark gradient fading up from the bottom edge, behind
--                        the whole text band.
--   "Flat"             — no gradient/shadow at all: a small rounded, translucent
--                        flat-colour panel sits directly behind JUST the text,
--                        so the rest of the image stays completely clean.
-- Either way the card IS the image (no text block below) — compact and premium.
function UICardComponent:_BuildOverlay(surface: Frame, spec: EntryLayoutConfig.EntrySpec)
	-- Image fills the entire card.
	local img = self:_MakeImage(surface, UDim2.fromScale(1, 1), true)
	img.ZIndex = 2

	-- Inventory tile: buyStyle "Quantity" means there's nothing to sell, so skip
	-- the whole price/scrim treatment entirely — just the square image with an
	-- owned-count badge overlaid in the bottom-right corner (and tags top-left,
	-- if the spec wants them). "The image AS the square, stuff inside of it."
	if spec.buyStyle == "Quantity" then
		if spec.showTags then
			local tags = self:_MakeTags(surface)
			if tags then
				tags.AnchorPoint = Vector2.new(0, 0)
				tags.Position = UDim2.fromOffset(8, 8)
				tags.Size = UDim2.new(1, -16, 0, 20)
				tags.ZIndex = 5
				for _, d in tags:GetDescendants() do
					if d:IsA("GuiObject") then
						d.ZIndex = 5
					end
				end
			end
		end
		local qty = self:_MakeQuantityBadge(surface)
		qty.AnchorPoint = Vector2.new(1, 1)
		qty.Position = UDim2.new(1, -8, 1, -8)
		qty.ZIndex = 5
		return
	end

	local useFlat = spec.overlayBg == "Flat"

	if not useFlat then
		-- Bottom scrim: a dark gradient fading from transparent (top) to opaque
		-- (bottom) so overlaid text reads over bright art without hiding the image.
		-- The frame spans the FULL card (not just the bottom fraction) so its
		-- rounded corners align EXACTLY with the card's own corners — sizing it
		-- smaller (with its own separate rounding) was what caused a visible seam/
		-- cutoff where the scrim's own top corners curved against the image at an
		-- arbitrary point partway down. Only the gradient decides where it darkens.
		local scrim = UIStyler.Frame("Scrim")
		scrim.BackgroundColor3 = Color3.new(0, 0, 0)
		scrim.BackgroundTransparency = 0
		scrim.Size = UDim2.fromScale(1, 1)
		scrim.ZIndex = 3
		local scrimGrad = Instance.new("UIGradient")
		scrimGrad.Rotation = 90
		scrimGrad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, 1),
			NumberSequenceKeypoint.new(0.7, 0.45),
			NumberSequenceKeypoint.new(1, 0.1),
		})
		scrimGrad.Parent = scrim
		scrim.Parent = surface
		self._scrim = scrim
		-- Match the card corner so the scrim's rounding is identical to the card's.
		local scrimCorner = UIStyler.Corner(16)
		scrimCorner.Parent = scrim
		self._scrimCorner = scrimCorner
	else
		-- Flat: a small rounded panel sized to just the text block (not the whole
		-- card width), a few px larger than the Info frame it sits behind so there's
		-- a clean margin. Coloured + made translucent in _Style.
		local flatBg = UIStyler.Frame("FlatBg")
		flatBg.AnchorPoint = Vector2.new(0, 1)
		flatBg.Position = UDim2.new(0, 4, 1, -4)
		flatBg.Size = UDim2.new(1, -8, 0, 56)
		flatBg.ZIndex = 4
		flatBg.Parent = surface
		self._flatBg = flatBg
		local flatCorner = UIStyler.Corner(10)
		flatCorner.Parent = flatBg
		self._flatBgCorner = flatCorner
	end

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
		-- Overlay's image spans the ENTIRE card (fillWidth, fromScale(1,1)), so
		-- its corners must match the card's own Large radius exactly — using the
		-- smaller Medium radius (correct for a padded thumbnail elsewhere) left the
		-- image's sharper corners visibly peeking past the scrim's more-rounded
		-- corner, which read as a hard "cutoff" right at each corner.
		local isFullBleed = self._spec.arrangement == "Overlay"
		self._imageCorner.CornerRadius = UDim.new(
			0,
			isFullBleed and radius or ThemeShape.Radius(theme, theme.Radii.Medium)
		)
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
	-- A Quantity-badge Overlay tile (inventory grid) skips name/price entirely
	-- (nothing to identify/price when it's just "how many do I own"), so both
	-- are nil-guarded here.
	local overlay = self._spec.arrangement == "Overlay"
	if self._name then
		self._name.FontFace = theme.Fonts.Subtitle
		self._name.TextSize = theme.TextSizes.Subtitle
		self._name.TextColor3 = overlay and Color3.new(1, 1, 1) or c.TextPrimary
	end

	if self._price then
		self._price.FontFace = theme.Fonts.Numeric
		self._price.TextSize = theme.TextSizes.Body
		self._price.TextColor3 = c.Accent
	end

	if self._desc then
		self._desc.FontFace = theme.Fonts.Body
		self._desc.TextSize = theme.TextSizes.Small
		self._desc.TextColor3 = c.TextSecondary
	end

	-- Overlay scrim: keep its rounded corner matched so it fits the card.
	if self._scrimCorner then
		self._scrimCorner.CornerRadius = UDim.new(0, radius)
	end
	-- Overlay Flat: a themed, SOMEWHAT TRANSPARENT panel behind just the text
	-- (no gradient, no shadow) — reads cleanly over any art without darkening it.
	if self._flatBg then
		self._flatBg.BackgroundColor3 = c.Background
		self._flatBg.BackgroundTransparency = 0.32
		self._flatBgCorner.CornerRadius = UDim.new(0, math.min(radius, 10))
	end

	-- Quantity badge (inventory rows): a quiet, secondary-coloured pill — it's
	-- informational, not an action, so it doesn't compete with name/price.
	if self._qtyLabel then
		self._qtyCorner.CornerRadius = UDim.new(1, 0)
		local qtyChip = self._qtyLabel.Parent :: Frame
		self:_SetColor(qtyChip, "BackgroundColor3", c.SurfaceRaised)
		self._qtyLabel.FontFace = theme.Fonts.Numeric
		self._qtyLabel.TextSize = theme.TextSizes.Small
		self._qtyLabel.TextColor3 = c.TextSecondary
	end
end

-- Patch the parts of a card that change without a purchase (affordability,
-- owned state, live balance-driven price re-renders) WITHOUT destroying and
-- rebuilding the whole card. This is what lets the shop update in place instead
-- of flickering/rebuilding every entry whenever currency changes — the same
-- kind of reload a real game would visibly suffer from on every value tick.
function UICardComponent:Update(props: { affordable: boolean?, owned: boolean? })
	if props.affordable ~= nil then
		self.Props.affordable = props.affordable
	end
	if props.owned ~= nil then
		self.Props.owned = props.owned
	end
	if not self._buy then
		return
	end
	local owned = self.Props.owned
	local affordable = self.Props.affordable
	self._buy.Props.textKey = owned and "shop.owned" or "shop.buy"
	self._buy.Props.variant = owned and "Ghost" or (affordable ~= false and "Success" or "Ghost")
	self._buy:SetContent(self._buy.Props)
	self._buy:SetEnabled(not owned and affordable ~= false)
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

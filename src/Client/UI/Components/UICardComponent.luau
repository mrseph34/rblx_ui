--!strict
-- Shop item card: icon swatch, name, tag pills, price chip and a buy button.
-- Renders entirely from a Shared.Types.ShopItem plus affordability state.
-- Extends UIComponentBase; the buy button and tag pills are child components,
-- so they re-theme automatically with everything else.
--
-- Extra props:
--   item        : Types.ShopItem (required)
--   currencyIcon: string emoji for the price chip
--   affordable  : boolean
--   owned       : boolean
--   onBuy       : (item) -> ()

local SharedTypes = require(game:GetService("ReplicatedStorage").Shared.Types)
local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
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

-- Deterministic pastel from the item id, so the placeholder swatch is stable
-- and distinct per item until real icon art replaces it.
local function monogramColor(id: string): Color3
	local hash = 0
	for i = 1, #id do
		hash = (hash * 31 + string.byte(id, i)) % 360
	end
	return Color3.fromHSV(hash / 360, 0.55, 0.85)
end

function UICardComponent:_Build(props: Types.UIComponentProps)
	local item = props.item :: SharedTypes.ShopItem
	local root = self.Root
	root.BackgroundTransparency = 0

	self._corner = UIStyler.Corner(16)
	self._corner.Parent = root
	self._stroke = UIStyler.Stroke(Color3.new(), 1.5)
	self._stroke.Parent = root
	self._gradient = UIStyler.Gradient(90, 0.1)
	self._gradient.Parent = root
	UIStyler.Padding(10).Parent = root

	UIStyler.ListLayout({
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
	}).Parent = root

	-- Icon swatch (placeholder monogram until iconId is provided).
	local iconHolder = UIStyler.Frame("Icon")
	iconHolder.Size = UDim2.new(1, 0, 0, 70)
	iconHolder.BackgroundColor3 = monogramColor(item.id)
	iconHolder.LayoutOrder = 1
	UIStyler.Corner(12).Parent = iconHolder
	iconHolder.Parent = root
	self._iconHolder = iconHolder

	if item.iconId ~= "" then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Image = item.iconId
		image.Parent = iconHolder
	else
		local mono = UIStyler.TextLabel("Mono")
		mono.Size = UDim2.fromScale(1, 1)
		mono.TextScaled = true
		mono.Text = string.upper(string.sub(TextConfig.Resolve(item.nameKey), 1, 1))
		mono.TextColor3 = Color3.new(1, 1, 1)
		UIStyler.Padding(14).Parent = mono
		mono.Parent = iconHolder
	end

	-- Tag pills row.
	local tagRow = UIStyler.Frame("Tags")
	tagRow.BackgroundTransparency = 1
	tagRow.Size = UDim2.new(1, 0, 0, 22)
	tagRow.LayoutOrder = 2
	UIStyler.ListLayout({
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 4),
	}).Parent = tagRow
	tagRow.Parent = root
	tagRow.Visible = item.tags ~= nil and #(item.tags :: {}) > 0
	if item.tags then
		for i, tag in item.tags do
			local badge = UIBadgeComponent.new()
			badge:Create(tagRow, { text = tag, variant = tag, layoutOrder = i })
			table.insert(self._badges, badge)
		end
	end

	-- Name.
	local name = UIStyler.TextLabel("Name")
	name.Size = UDim2.new(1, 0, 0, 22)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = TextConfig.Resolve(item.nameKey)
	name.LayoutOrder = 3
	name.Parent = root
	self._name = name

	-- Price chip.
	local price = UIStyler.TextLabel("Price")
	price.Size = UDim2.new(1, 0, 0, 20)
	price.TextXAlignment = Enum.TextXAlignment.Left
	price.Text = string.format("%s %s", props.currencyIcon or "", tostring(item.price))
	price.LayoutOrder = 4
	price.Parent = root
	self._price = price

	-- Buy button (child component).
	local buy = UIButtonComponent.new()
	self._buy = buy
	buy:Create(root, {
		textKey = props.owned and "shop.owned" or "shop.buy",
		variant = props.owned and "Ghost" or (props.affordable and "Success" or "Ghost"),
		enabled = not props.owned and props.affordable ~= false,
		size = UDim2.new(1, 0, 0, 38),
		layoutOrder = 5,
		onClick = function()
			if props.onBuy then
				props.onBuy(item)
			end
			self:PlayAnimation("Pulse")
		end,
	})
end

function UICardComponent:_Style(theme: Types.UITheme)
	local c = theme.Colors
	self:_Tween(self.Root, theme.Animations.ThemeSwap, { BackgroundColor3 = c.SurfaceRaised })
	self._corner.CornerRadius = UDim.new(0, theme.Radii.Large)
	self._stroke.Color = c.Stroke
	self._stroke.Thickness = theme.Effects.StrokeThickness
	self._stroke.Transparency = 0.35
	self._gradient.Enabled = theme.Effects.UseGradients
	self._gradient.Color = UIStyler.Gradient(90, theme.Effects.GradientIntensity).Color

	self._name.FontFace = theme.Fonts.Subtitle
	self._name.TextSize = theme.TextSizes.Subtitle
	self._name.TextColor3 = c.TextPrimary

	self._price.FontFace = theme.Fonts.Numeric
	self._price.TextSize = theme.TextSizes.Body
	self._price.TextColor3 = c.Accent
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

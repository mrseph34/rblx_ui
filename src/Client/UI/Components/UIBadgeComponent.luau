--!strict
-- Small pill label for states/tags ("NEW", "RARE", ...). Fully themed; color
-- comes from a token name or an explicit variant. Used by cards and anywhere a
-- status chip is needed.
--
-- Extra props:
--   text / textKey
--   variant : "New" | "Sale" | "Rare" | "Limited" | "Popular" | token name

local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local CardSpacing = require(script.Parent.Parent.Config.CardSpacingConfig)
local UIComponentBase = require(script.Parent.UIComponentBase)

local UIBadgeComponent = setmetatable({}, { __index = UIComponentBase })
UIBadgeComponent.__index = UIBadgeComponent

-- Maps a tag variant to a theme color token name.
local VARIANT_TOKEN = {
	New = "Success",
	Sale = "Error",
	Rare = "Secondary",
	Limited = "Warning",
	Popular = "Primary",
}

function UIBadgeComponent.new()
	local self = UIComponentBase.new("UIBadge")
	return setmetatable(self, UIBadgeComponent)
end

function UIBadgeComponent:_Build(props: Types.UIComponentProps)
	local root = self.Root
	root.BackgroundTransparency = 0
	root.AutomaticSize = Enum.AutomaticSize.X
	if not props.size then
		-- Compact chip: the colour already makes it pop, so it stays small and
		-- doesn't crowd the more important name/price/buy. Height comes from
		-- CardSpacingConfig — this MUST match CardSpacing.Height.TagRow exactly
		-- (the card's tag row is sized to fit this badge with zero slack).
		local h = CardSpacing.Height.TagRow
		root.Size = UDim2.fromOffset(0, h)
		self._baseSize = UDim2.fromOffset(40, h)
	end

	self._corner = UIStyler.Corner(1000)
	self._corner.Parent = root
	UIStyler.PaddingXY(5, 1).Parent = root

	local label = UIStyler.TextLabel("Label")
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.Parent = root
	self._label = label

	self:SetContent(props)
end

function UIBadgeComponent:SetContent(props: Types.UIComponentProps)
	self._label.Text = TextConfig.Resolve(props.textKey or props.text)
	if self.Theme then
		self:_Style(self.Theme)
	end
end

function UIBadgeComponent:_Style(theme: Types.UITheme)
	local c = theme.Colors
	local variant = self.Props.variant or "New"
	local tokenName = VARIANT_TOKEN[variant] or variant
	local fill = (c :: any)[tokenName] or c.Primary

	self.Root.BackgroundColor3 = fill
	self._corner.CornerRadius = UDim.new(0, theme.Radii.Pill)
	self._label.FontFace = theme.Fonts.Button
	-- Smaller than Small — badges are secondary info; colour carries them.
	self._label.TextSize = math.max(9, theme.TextSizes.Small - 3)
	self._label.TextColor3 = c.TextOnPrimary
end

return UIBadgeComponent

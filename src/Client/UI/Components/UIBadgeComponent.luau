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
local TextScaleConfig = require(script.Parent.Parent.Config.TextScaleConfig)
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
		-- doesn't crowd the more important name/price/buy. Height FILLS the
		-- parent row exactly (both callers always parent into a row/badgeArea
		-- frame already sized to CardSpacing.Height.TagRow, Scale or pixel) —
		-- this can't drift out of sync with the row because it never computes
		-- its own height independently.
		root.Size = UDim2.fromScale(0, 1)
		self._baseSize = UDim2.fromScale(0, 1)
	end

	self._corner = UIStyler.Corner(1000)
	self._corner.Parent = root
	-- NO UIPadding here: root is AutomaticSize.X off the label, and the label
	-- is ALSO AutomaticSize.X — a UIPadding on root fighting that combination
	-- produced unstable/incorrect sizing (confirmed by direct testing across
	-- packs). The label is instead given a bit of extra horizontal room
	-- directly via its own Size below.

	local label = UIStyler.TextLabel("Label")
	-- AutomaticSize.X stays (root itself AutomaticSizes off this label's real
	-- text width, so the chip hugs the text) — but the text now scales via
	-- TextScaled per TextScaleConfig instead of a fixed pixel size.
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	-- TextScaled must be the LAST text-wrap-related assignment — setting
	-- TextWrapped afterward (even to false) silently reverts TextScaled back
	-- to false (confirmed via a live Studio test). AutomaticSize.X growing to
	-- fit the unwrapped text means wrapping never actually triggers anyway.
	label.TextScaled = true
	self._labelConstraint = UIStyler.TextSizeConstraint(16, 6)
	self._labelConstraint.Parent = label
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
	self._label.TextColor3 = c.TextOnPrimary
	if self._labelConstraint then
		-- Smaller than Small — badges are secondary info; colour carries them.
		self._labelConstraint.MaxTextSize = TextScaleConfig.ScaledCap(math.max(9, theme.TextSizes.Small - 3))
	end
end

return UIBadgeComponent

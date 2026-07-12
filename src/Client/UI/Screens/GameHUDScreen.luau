--!strict
-- Always-on HUD. Renders stat readouts, timers, a health bar and an objectives
-- list from HUDConfig into anchored regions, and hosts the toast stack. Values
-- update in place via Update({ values = ... }); config decides which elements
-- exist and where.

local GuiService = game:GetService("GuiService")

local UIStyler = require(script.Parent.Parent.UIStyler)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local HUDConfig = require(script.Parent.Parent.Config.HUDConfig)
local UIScreenBase = require(script.Parent.UIScreenBase)
local UIProgressBarComponent = require(script.Parent.Parent.Components.UIProgressBarComponent)
local UIToastComponent = require(script.Parent.Parent.Components.UIToastComponent)
local UINotificationComponent = require(script.Parent.Parent.Components.UINotificationComponent)

local GameHUDScreen = setmetatable({}, { __index = UIScreenBase })
GameHUDScreen.__index = GameHUDScreen

-- Region id -> (anchor, position, list direction/alignment) on screen.
-- valign matters for bottom regions: the container's box is a fixed-ish size
-- (AutomaticSize doesn't reliably shrink a bottom-anchored, list-laid-out frame
-- in every case), so with the ListLayout's default Top alignment its CONTENT can
-- end up sitting near the top of that box — visibly far from the true bottom
-- edge the region is supposed to hug (this is exactly why health/mana/stamina
-- were floating mid-screen instead of low, colliding with the nav rail).
-- VerticalAlignment.Bottom makes content hug the box's bottom edge regardless.
-- Pure Scale fractions of Root (never a fixed pixel Offset) — Root itself
-- holds a fixed 1.89 aspect ratio (see _BuildContent), so every element
-- positioned/sized as a fraction of it scales consistently at any real
-- viewport instead of staying a constant absolute pixel size/margin.
local EDGE_MARGIN = 0.02

local REGION_LAYOUT = {
	-- Fixed pixel Offset (deliberate exception to the Scale rule above): this
	-- has to clear Roblox's OWN top-left client chrome (menu/settings icons),
	-- which is itself a constant pixel footprint regardless of the game's UI
	-- scale — a Scale-relative position can't reliably dodge a fixed-size
	-- external element.
	TopLeft = { anchor = Vector2.new(0, 0), pos = UDim2.new(0, 215, 0, 17), dir = "V", align = "Left", valign = "Top" },
	TopCenter = { anchor = Vector2.new(0.5, 0), pos = UDim2.fromScale(0.5, EDGE_MARGIN), dir = "V", align = "Center", valign = "Top" },
	TopRight = { anchor = Vector2.new(1, 0), pos = UDim2.fromScale(1 - EDGE_MARGIN, EDGE_MARGIN), dir = "V", align = "Right", valign = "Top" },
	BottomLeft = { anchor = Vector2.new(0, 1), pos = UDim2.fromScale(EDGE_MARGIN, 1 - EDGE_MARGIN), dir = "V", align = "Left", valign = "Bottom" },
	BottomCenter = { anchor = Vector2.new(0.5, 1), pos = UDim2.fromScale(0.5, 1 - EDGE_MARGIN), dir = "V", align = "Center", valign = "Bottom" },
	-- Offset left of the toast stack so a relocated element doesn't collide.
	BottomRight = { anchor = Vector2.new(1, 1), pos = UDim2.fromScale(1 - EDGE_MARGIN, 1 - 0.1), dir = "V", align = "Right", valign = "Bottom" },
}

function GameHUDScreen.new()
	local self = UIScreenBase.new("GameHUDScreen", 2)
	self._values = table.clone(HUDConfig.DefaultValues)
	self._elementViews = {} :: { [string]: any }
	self._bars = {} :: { [string]: any }
	self._objectives = {}
	self._toasts = {}
	return setmetatable(self, GameHUDScreen)
end

-- Currency elements relocate to the active pack's MoneyRegion; everything else
-- keeps its HUDConfig region — UNLESS a per-element override (pack.HUD.Regions
-- or a runtime SetElementRegion call) says otherwise. This is what lets each
-- pack, or the game at runtime, put the money / skills / any HUD element in a
-- different spot without editing HUDConfig.
local MONEY_IDS = { coins = true, gems = true }

-- The region an element should actually render in, honouring (in priority):
-- explicit override > money region (for currency) > its HUDConfig region.
function GameHUDScreen:_EffectiveRegion(element: any): string
	if self._regionOverrides and self._regionOverrides[element.id] then
		return self._regionOverrides[element.id]
	end
	if self._packRegions and self._packRegions[element.id] then
		return self._packRegions[element.id]
	end
	if MONEY_IDS[element.id] then
		return self._moneyRegion
	end
	return element.region
end

function GameHUDScreen:_EffectiveElementsForRegion(region: string)
	local out = {}
	for _, element in HUDConfig.Elements do
		if self:_EffectiveRegion(element) == region then
			table.insert(out, element)
		end
	end
	table.sort(out, function(a, b)
		return a.order < b.order
	end)
	return out
end

-- Runtime reposition: move a HUD element to a region and rebuild. Persisted in
-- _regionOverrides so it survives pack changes until explicitly cleared.
function GameHUDScreen:SetElementRegion(elementId: string, region: string)
	self._regionOverrides = self._regionOverrides or {}
	self._regionOverrides[elementId] = region
	self:Rebuild()
end

-- Apply a whole layout-preset's HUD block in ONE rebuild: relocate the money
-- chips, apply any per-element region overrides, and (optionally) override the
-- HUD scale. Used by UILayoutController so switching presets is a single
-- relayout instead of one rebuild per moved element.
function GameHUDScreen:ApplyLayout(opts: { money: string?, regions: { [string]: string }?, scaleOverride: number? })
	self._regionOverrides = {} -- a preset fully defines placement; start clean
	if opts.money then
		self._regionOverrides.coins = opts.money
		self._regionOverrides.gems = opts.money
	end
	if opts.regions then
		for id, region in opts.regions do
			self._regionOverrides[id] = region
		end
	end
	-- nil clears any earlier override so the pack's own scale takes back over.
	self._scaleOverride = opts.scaleOverride
	self:Rebuild()
end

-- Tear down and rebuild HUD content from the current pack (used when the pack
-- changes at runtime, e.g. the Theme Editor's pack picker / test harness).
function GameHUDScreen:Rebuild()
	if not self._built then
		return
	end
	for _, badge in self._toasts do
		badge:Destroy()
	end
	for _, child in self.Root:GetChildren() do
		child:Destroy()
	end
	self._elementViews = {}
	self._bars = {}
	self._objectives = {}
	self._toasts = {}
	self:_BuildContent()
	self:_RefreshValues()
end

function GameHUDScreen:_BuildContent()
	-- No AspectRatioConstraint on Root: unlike a centered panel (ShopScreen
	-- etc.), every region below (TopLeft/TopRight/BottomLeft/…) is anchored
	-- directly to one of ROOT'S OWN corners/edges via AnchorPoint + a Scale
	-- position fraction. Root has AnchorPoint (0,0) — constraining IT would
	-- shrink it flush to the top-left, dragging every non-top-left-anchored
	-- region (TopRight, BottomRight, BottomCenter, …) away from the TRUE
	-- screen's actual corner/edge along with it (confirmed: at this
	-- viewport's aspect ratio a 1.89 lock left ~400px of unused screen on
	-- the right, with TopRight/BottomRight rendering ~400px short of the
	-- real edge). With Root left as the true full screen, each region's own
	-- corner/edge anchor already does the right thing with no extra
	-- constraint needed — the fix here is REMOVING the lock, not moving it.

	-- Compensates a real, reproducible engine quirk in this environment (see
	-- UINavRailController's own note on the same fix): even with
	-- ScreenGui.IgnoreGuiInset = true, every Position on this Root still
	-- renders shifted UP by exactly GuiService:GetGuiInset().Y — confirmed
	-- via direct measurement (Root.AbsolutePosition.Y read -58 with
	-- Position={0,0}, exactly matching a 58px inset). Shifting Root DOWN by
	-- that same amount (and shrinking its height to match) cancels the quirk
	-- out, so every region built below actually lands where its Position
	-- fraction/offset says it should, instead of rendering ~58px too high
	-- (invisible off the top of the screen for anything using a small margin
	-- like TopLeft's fixed pixel offset).
	local insetY = GuiService:GetGuiInset().Y
	self.Root.Position = UDim2.new(0, 0, 0, insetY)
	self.Root.Size = UDim2.new(1, 0, 1, -insetY)

	local scale = Instance.new("UIScale")
	scale.Parent = self.Root
	self._scale = scale

	local packHUD = self.ThemeController:GetPack().HUD
	self._moneyRegion = packHUD.MoneyRegion
	self._moneyIconSide = packHUD.MoneyIconSide
	self._packRegions = packHUD.Regions
	for region, layout in REGION_LAYOUT do
		local container = UIStyler.Frame(region)
		container.BackgroundTransparency = 1
		container.AnchorPoint = layout.anchor
		container.Position = layout.pos
		container.Size = UDim2.fromScale(0.19, 0)
		container.AutomaticSize = Enum.AutomaticSize.Y
		UIStyler.ListLayout({
			-- Tight (was 6): meters no longer have a separate name row above
			-- them, so a small gap between each stacked element reads as one
			-- cohesive HUD group instead of spread-out separate rows.
			Padding = UDim.new(0, 3),
			HorizontalAlignment = Enum.HorizontalAlignment[layout.align],
			-- Belt-and-suspenders with AutomaticSize: if the box doesn't shrink to
			-- exactly fit its content, Bottom/Top alignment still pins the content
			-- to the correct edge instead of leaving it stranded mid-box.
			VerticalAlignment = Enum.VerticalAlignment[layout.valign],
		}).Parent = container
		container.Parent = self.Root
		self._elementViews[region] = container

		if region == "TopRight" then
			self.ScreenController:RegisterHighlightTarget("hud.topRight", container)
		end

		for _, element in self:_EffectiveElementsForRegion(region) do
			self:_BuildElement(container, element)
		end
	end

	-- Objectives panel (lower-left, above the vitals stack so they don't overlap).
	local objectives = UIStyler.Frame("Objectives")
	objectives.BackgroundTransparency = 1
	objectives.AnchorPoint = Vector2.new(0, 1)
	objectives.Position = UDim2.fromScale(EDGE_MARGIN, 1 - 0.14)
	objectives.Size = UDim2.fromScale(0.21, 0)
	objectives.AutomaticSize = Enum.AutomaticSize.Y
	UIStyler.ListLayout({ Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Left }).Parent = objectives
	objectives.Parent = self.Root
	self._objectivesHolder = objectives

	-- Toast stack (bottom-right).
	local toastStack = UIStyler.Frame("Toasts")
	toastStack.BackgroundTransparency = 1
	toastStack.AnchorPoint = Vector2.new(1, 1)
	toastStack.Position = UDim2.fromScale(1 - EDGE_MARGIN, 1 - EDGE_MARGIN)
	toastStack.Size = UDim2.fromScale(0.24, 0.34)
	UIStyler.ListLayout({
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	}).Parent = toastStack
	toastStack.Parent = self.Root
	self._toastStack = toastStack

	-- Banner slot (top-center, below the top HUD row) for prominent
	-- level-up / achievement notifications.
	local bannerSlot = UIStyler.Frame("Banner")
	bannerSlot.BackgroundTransparency = 1
	bannerSlot.AnchorPoint = Vector2.new(0.5, 0)
	bannerSlot.Position = UDim2.fromScale(0.5, 0.15)
	bannerSlot.Size = UDim2.fromScale(0.29, 0.1)
	bannerSlot.Parent = self.Root
	self._bannerSlot = bannerSlot

	self:_ApplyPackScale()
end

-- Prominent top-center banner (level-up, achievement, unlock).
function GameHUDScreen:PushBanner(data: any)
	self:_EnsureBuilt()
	self:_PlaySound(data.variant == "Info" and "Open" or "Success")
	if self._banner then
		self._banner:Destroy()
	end
	local banner = UINotificationComponent.new()
	self._banner = banner
	banner:Create(self._bannerSlot, {
		titleKey = data.titleKey,
		title = data.title,
		bodyKey = data.bodyKey,
		body = data.body,
		icon = data.icon,
		variant = data.variant,
		duration = data.duration,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		onDone = function()
			if self._banner == banner then
				self._banner = nil
			end
		end,
	})
	banner:Play()
end

function GameHUDScreen:_BuildElement(container: Frame, element: any)
	if element.format == "Bar" then
		-- The meter's name lives INSIDE the bar now (overlaid on the fill, left-
		-- aligned, value right-aligned — see UIProgressBarComponent's `label`
		-- prop) instead of a separate text row stacked above it. One row per
		-- meter instead of two, so three vitals stack in a lot less vertical
		-- space and the whole group reads as a tighter unit.
		-- Width fills the container (itself a Scale fraction of Root — see
		-- REGION_LAYOUT) instead of a fixed pixel Offset. Height stays a
		-- modest fixed px: the container is AutomaticSize.Y (content-driven),
		-- so a Scale height here would resolve against that circularly.
		local wrapper = UIStyler.Frame("bar_" .. element.id)
		wrapper.BackgroundTransparency = 1
		wrapper.Size = UDim2.new(1, 0, 0, 22)
		local bar = UIProgressBarComponent.new()
		bar:Create(wrapper, {
			value = self._values[element.id] or 0,
			maxValue = element.maxValue or 100,
			colorToken = element.colorToken,
			label = string.format("%s %s", element.icon or "", TextConfig.Resolve(element.labelKey)),
			size = UDim2.fromScale(1, 1),
		})
		wrapper.Parent = container
		self._bars[element.id] = bar
		self._elementViews[element.id] = { root = wrapper }
	else
		local chip = UIStyler.Frame("chip_" .. element.id)
		chip.BackgroundTransparency = 0
		chip.Size = UDim2.fromOffset(0, 34)
		chip.AutomaticSize = Enum.AutomaticSize.X
		UIStyler.Corner(1000).Parent = chip
		-- NO UIPadding here: chip is AutomaticSize.X off the label, and the
		-- label is ALSO AutomaticSize.X — a UIPadding fighting that
		-- combination produces unstable/incorrect sizing (same fix already
		-- applied to UIBadgeComponent/_MakePriceChip). Margin instead comes
		-- from a small fixed horizontal ListLayout padding plus leading/
		-- trailing spaces baked into the text content (see _RefreshValues).
		UIStyler.ListLayout({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
		}).Parent = chip

		local text = UIStyler.TextLabel("Value")
		text.AutomaticSize = Enum.AutomaticSize.X
		text.Size = UDim2.fromScale(0, 0.7)
		text.TextScaled = true
		local textConstraint = UIStyler.TextSizeConstraint(18, 9)
		textConstraint.Parent = text
		text.Parent = chip
		chip.Parent = container
		self._elementViews[element.id] = { root = chip, label = text, element = element, labelConstraint = textConstraint }
	end
end

-- ---- toasts -----------------------------------------------------------

function GameHUDScreen:PushToast(data: any)
	self:_EnsureBuilt()
	if data.variant == "Success" then
		self:_PlaySound("Success")
	elseif data.variant == "Error" then
		self:_PlaySound("Error")
	end
	local toast = UIToastComponent.new()
	-- No `size` prop: UIToastComponent's own _Build sets Root.Size (a fixed
	-- Scale fraction of the toast stack) unconditionally, so a size passed
	-- here would be silently ignored anyway.
	toast:Create(self._toastStack, {
		textKey = data.textKey,
		text = data.text,
		variant = data.variant,
		icon = data.icon,
		duration = data.duration,
		onDone = function()
			local index = table.find(self._toasts, toast)
			if index then
				table.remove(self._toasts, index)
			end
		end,
	})
	table.insert(self._toasts, toast)
	toast:Play()
end

-- ---- values -----------------------------------------------------------

function GameHUDScreen:Update(data: any)
	if not data or not data.values then
		if data and data.objectives then
			self:_RenderObjectives(data.objectives)
		end
		return
	end
	for id, value in data.values do
		self._values[id] = value
	end
	self:_RefreshValues()
	if data.objectives then
		self:_RenderObjectives(data.objectives)
	end
end

function GameHUDScreen:_RefreshValues()
	local theme = self:GetTheme()
	for id, view in self._elementViews do
		if typeof(view) == "table" and view.element then
			local element = view.element
			local value = self._values[id] or 0
			local display = element.format == "Time" and HUDConfig.FormatTime(value) or tostring(math.floor(value))
			-- Currency chips honour the pack's icon side; other chips keep
			-- icon-left. Leading/trailing space: chip has no UIPadding (see
			-- _BuildElement's comment), so the padded string itself keeps
			-- text off the pill's edge.
			local icon = element.icon or ""
			if MONEY_IDS[element.id] and self._moneyIconSide == "Right" then
				view.label.Text = string.format(" %s %s ", display, icon)
			else
				view.label.Text = string.format(" %s %s ", icon, display)
			end
			view.label.FontFace = theme.Fonts.Numeric
			if view.labelConstraint then
				view.labelConstraint.MaxTextSize = theme.TextSizes.Body
			end
			view.label.TextColor3 = (theme.Colors :: any)[element.colorToken] or theme.Colors.TextPrimary
			view.root.BackgroundColor3 = theme.Colors.SurfaceRaised
		end
	end
	for id, bar in self._bars do
		bar:Set(self._values[id] or 0)
	end
end

function GameHUDScreen:_RenderObjectives(objectives: any)
	for _, item in self._objectives do
		item:Destroy()
	end
	table.clear(self._objectives)
	local theme = self:GetTheme()
	for i, objective in objectives do
		local row = UIStyler.TextLabel("obj_" .. i)
		row.Size = UDim2.new(1, 0, 0, 22)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextScaled = true
		local rowConstraint = UIStyler.TextSizeConstraint(18, 9)
		rowConstraint.Parent = row
		row.Text = string.format(
			"%s %s",
			objective.done and "✅" or "⬜",
			TextConfig.Resolve(objective.textKey or objective.text)
		)
		row.FontFace = theme.Fonts.Body
		rowConstraint.MaxTextSize = theme.TextSizes.Body
		row.TextColor3 = objective.done and theme.Colors.Success or theme.Colors.TextSecondary
		row.LayoutOrder = i
		row.Parent = self._objectivesHolder
		table.insert(self._objectives, row)
	end
end

function GameHUDScreen:_ApplyPackScale()
	local pack = self.ThemeController:GetPack()
	if self._scale then
		-- A layout preset can override the pack's HUD scale (Compact/Cinematic
		-- shrink it for more play space); nil falls back to the pack's own scale.
		self._scale.Scale = self._scaleOverride or pack.HUD.Scale
	end
	if self._objectivesHolder then
		self._objectivesHolder.Visible = pack.HUD.ShowObjectives
	end
end

function GameHUDScreen:_OnShow()
	self:_RefreshValues()
	self:_ApplyPackScale()
end

return GameHUDScreen

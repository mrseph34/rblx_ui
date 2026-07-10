--!strict
-- Always-on HUD. Renders stat readouts, timers, a health bar and an objectives
-- list from HUDConfig into anchored regions, and hosts the toast stack. Values
-- update in place via Update({ values = ... }); config decides which elements
-- exist and where.

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
local REGION_LAYOUT = {
	TopLeft = { anchor = Vector2.new(0, 0), pos = UDim2.new(0, 16, 0, 16), dir = "V", align = "Left" },
	TopCenter = { anchor = Vector2.new(0.5, 0), pos = UDim2.new(0.5, 0, 0, 16), dir = "V", align = "Center" },
	TopRight = { anchor = Vector2.new(1, 0), pos = UDim2.new(1, -16, 0, 16), dir = "V", align = "Right" },
	BottomLeft = { anchor = Vector2.new(0, 1), pos = UDim2.new(0, 16, 1, -16), dir = "V", align = "Left" },
	BottomCenter = { anchor = Vector2.new(0.5, 1), pos = UDim2.new(0.5, 0, 1, -16), dir = "V", align = "Center" },
	-- Offset left of the toast stack so a relocated element doesn't collide.
	BottomRight = { anchor = Vector2.new(1, 1), pos = UDim2.new(1, -16, 1, -80), dir = "V", align = "Right" },
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
		container.Size = UDim2.fromOffset(240, 200)
		container.AutomaticSize = Enum.AutomaticSize.Y
		UIStyler.ListLayout({
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment[layout.align],
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
	objectives.Position = UDim2.new(0, 16, 1, -168)
	objectives.Size = UDim2.fromOffset(260, 120)
	objectives.AutomaticSize = Enum.AutomaticSize.Y
	UIStyler.ListLayout({ Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Left }).Parent = objectives
	objectives.Parent = self.Root
	self._objectivesHolder = objectives

	-- Toast stack (bottom-right).
	local toastStack = UIStyler.Frame("Toasts")
	toastStack.BackgroundTransparency = 1
	toastStack.AnchorPoint = Vector2.new(1, 1)
	toastStack.Position = UDim2.new(1, -16, 1, -16)
	toastStack.Size = UDim2.fromOffset(300, 260)
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
	bannerSlot.Position = UDim2.new(0.5, 0, 0, 128)
	bannerSlot.Size = UDim2.fromOffset(360, 76)
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
		local wrapper = UIStyler.Frame("bar_" .. element.id)
		wrapper.BackgroundTransparency = 1
		wrapper.Size = UDim2.fromOffset(220, 40)
		local label = UIStyler.TextLabel("Label")
		label.Size = UDim2.new(1, 0, 0, 18)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = string.format("%s %s", element.icon or "", TextConfig.Resolve(element.labelKey))
		label.Parent = wrapper
		local bar = UIProgressBarComponent.new()
		bar:Create(wrapper, {
			value = self._values[element.id] or 0,
			maxValue = element.maxValue or 100,
			colorToken = element.colorToken,
			showText = true,
			position = UDim2.fromOffset(0, 20),
			size = UDim2.new(1, 0, 0, 16),
		})
		wrapper.Parent = container
		self._bars[element.id] = bar
		self._elementViews[element.id] = { root = wrapper, label = label }
	else
		local chip = UIStyler.Frame("chip_" .. element.id)
		chip.BackgroundTransparency = 0
		chip.Size = UDim2.fromOffset(150, 34)
		chip.AutomaticSize = Enum.AutomaticSize.X
		UIStyler.Corner(1000).Parent = chip
		UIStyler.PaddingXY(12, 4).Parent = chip
		UIStyler.ListLayout({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
		}).Parent = chip

		local text = UIStyler.TextLabel("Value")
		text.AutomaticSize = Enum.AutomaticSize.X
		text.Size = UDim2.fromScale(0, 1)
		text.Parent = chip
		chip.Parent = container
		self._elementViews[element.id] = { root = chip, label = text, element = element }
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
	toast:Create(self._toastStack, {
		textKey = data.textKey,
		text = data.text,
		variant = data.variant,
		icon = data.icon,
		duration = data.duration,
		size = UDim2.new(0, 300, 0, 44),
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
			-- Currency chips honour the pack's icon side; other chips keep icon-left.
			local icon = element.icon or ""
			if MONEY_IDS[element.id] and self._moneyIconSide == "Right" then
				view.label.Text = string.format("%s %s", display, icon)
			else
				view.label.Text = string.format("%s %s", icon, display)
			end
			view.label.FontFace = theme.Fonts.Numeric
			view.label.TextSize = theme.TextSizes.Body
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
		row.Text = string.format(
			"%s %s",
			objective.done and "✅" or "⬜",
			TextConfig.Resolve(objective.textKey or objective.text)
		)
		row.FontFace = theme.Fonts.Body
		row.TextSize = theme.TextSizes.Body
		row.TextColor3 = objective.done and theme.Colors.Success or theme.Colors.TextSecondary
		row.LayoutOrder = i
		row.Parent = self._objectivesHolder
		table.insert(self._objectives, row)
	end
end

function GameHUDScreen:_ApplyPackScale()
	local pack = self.ThemeController:GetPack()
	if self._scale then
		self._scale.Scale = pack.HUD.Scale
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

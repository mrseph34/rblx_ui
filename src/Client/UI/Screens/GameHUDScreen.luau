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

local GameHUDScreen = setmetatable({}, { __index = UIScreenBase })
GameHUDScreen.__index = GameHUDScreen

-- Region id -> (anchor, position, list direction/alignment) on screen.
local REGION_LAYOUT = {
	TopLeft = { anchor = Vector2.new(0, 0), pos = UDim2.new(0, 16, 0, 16), dir = "V", align = "Left" },
	TopCenter = { anchor = Vector2.new(0.5, 0), pos = UDim2.new(0.5, 0, 0, 16), dir = "V", align = "Center" },
	TopRight = { anchor = Vector2.new(1, 0), pos = UDim2.new(1, -16, 0, 16), dir = "V", align = "Right" },
	BottomLeft = { anchor = Vector2.new(0, 1), pos = UDim2.new(0, 16, 1, -16), dir = "V", align = "Left" },
	BottomCenter = { anchor = Vector2.new(0.5, 1), pos = UDim2.new(0.5, 0, 1, -16), dir = "V", align = "Center" },
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

function GameHUDScreen:_BuildContent()
	local scale = Instance.new("UIScale")
	scale.Parent = self.Root
	self._scale = scale

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

		for _, element in HUDConfig.GetElementsForRegion(region) do
			self:_BuildElement(container, element)
		end
	end

	-- Objectives panel (bottom-left), populated on demand.
	local objectives = UIStyler.Frame("Objectives")
	objectives.BackgroundTransparency = 1
	objectives.AnchorPoint = Vector2.new(0, 1)
	objectives.Position = UDim2.new(0, 16, 1, -60)
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

	self:_ApplyPackScale()
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
			view.label.Text = string.format("%s %s", element.icon or "", display)
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

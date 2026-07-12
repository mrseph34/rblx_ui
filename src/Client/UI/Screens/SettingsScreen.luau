--!strict
-- Settings / options menu. Renders SettingsConfig into a themed panel: titled
-- sections, each a scroll of consistent rows (toggle / slider / dropdown) built
-- from the shared components. Values live in a state table and fire onChange so a
-- game can persist them; the demo just holds them in memory.
--
-- This is the text-heavy "menu pack" counterpart to the shop — same panel chrome
-- and theming, different content driven entirely by data. Add a setting = add a
-- row in SettingsConfig; no screen changes.

local UIStyler = require(script.Parent.Parent.UIStyler)
local SettingsConfig = require(script.Parent.Parent.Config.SettingsConfig)
local UIScreenBase = require(script.Parent.UIScreenBase)
local UIPanelComponent = require(script.Parent.Parent.Components.UIPanelComponent)
local UIToggleComponent = require(script.Parent.Parent.Components.UIToggleComponent)
local UISliderComponent = require(script.Parent.Parent.Components.UISliderComponent)
local UIDropdownComponent = require(script.Parent.Parent.Components.UIDropdownComponent)

local SettingsScreen = setmetatable({}, { __index = UIScreenBase })
SettingsScreen.__index = SettingsScreen

function SettingsScreen.new()
	local self = UIScreenBase.new("SettingsScreen", 17)
	self._state = SettingsConfig.Defaults()
	self._rows = {}
	-- Optional injected callback: (id, value) -> () when a setting changes.
	self._onChange = nil :: ((string, any) -> ())?
	return setmetatable(self, SettingsScreen)
end

function SettingsScreen:SetChangeHandler(fn: (string, any) -> ())
	self._onChange = fn
end

function SettingsScreen:_BuildContent()
	-- The AspectRatioConstraint lives on the PANEL, not Root — see
	-- ShopScreen's note for the full explanation. 0.5/0.8*1.89 reproduces the
	-- panel's own previous effective shape (0.5 x 0.8 of a 1.89-locked Root)
	-- exactly, just correctly centered now instead of dragged top-left.
	local panel = UIPanelComponent.new()
	self._panel = panel
	self:_SetAnimatedPanel(panel)
	panel:Create(self.Root, {
		titleKey = "settings.title",
		size = UDim2.fromScale(0.5, 0.8),
		onClose = function()
			self.ScreenController:HideScreen("settings")
		end,
	})
	local panelAspect = UIStyler.AspectRatio(0.5 / 0.8 * 1.89, Enum.DominantAxis.Width)
	panelAspect.Parent = panel.Root

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Sections"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, -16, 1, -12)
	scroll.Position = UDim2.fromOffset(8, 8)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.Parent = panel.Body
	-- Breathing room so the first/last rows and open dropdowns aren't clipped.
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = scroll
	UIStyler.ListLayout({ Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Left }).Parent = scroll
	self._scroll = scroll

	self:_BuildRows()
end

function SettingsScreen:_BuildRows()
	for _, row in self._rows do
		row:Destroy()
	end
	table.clear(self._rows)

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	for _, section in SettingsConfig.Sections do
		self:_ScreenLabel(self._scroll, self:_R(section.titleKey), "Accent", "Subtitle", nextOrder())
		for _, row in section.rows do
			self:_BuildRow(row, nextOrder())
		end
	end
end

function SettingsScreen:_ApplyChange(id: string, value: any)
	self._state[id] = value
	if self._onChange then
		self._onChange(id, value)
	end
end

function SettingsScreen:_BuildRow(row: any, layoutOrder: number)
	local value = self._state[row.id]
	if row.kind == "Toggle" then
		local toggle = UIToggleComponent.new()
		toggle:Create(self._scroll, {
			labelKey = row.labelKey,
			value = value,
			layoutOrder = layoutOrder,
			onChanged = function(v: boolean)
				self:_ApplyChange(row.id, v)
			end,
		})
		table.insert(self._rows, toggle)
	elseif row.kind == "Slider" then
		local slider = UISliderComponent.new()
		slider:Create(self._scroll, {
			labelKey = row.labelKey,
			min = row.min, max = row.max, step = row.step,
			decimals = row.decimals,
			value = value,
			layoutOrder = layoutOrder,
			onChanged = function(v: number)
				self:_ApplyChange(row.id, v)
			end,
		})
		table.insert(self._rows, slider)
	elseif row.kind == "Dropdown" then
		-- Resolve option text keys for display.
		local options = {}
		for _, opt in row.options do
			table.insert(options, { id = opt.id, text = self:_R(opt.textKey) })
		end
		local dropdown = UIDropdownComponent.new()
		dropdown:Create(self._scroll, {
			labelKey = row.labelKey,
			options = options,
			value = value,
			layoutOrder = layoutOrder,
			onChanged = function(id: string)
				self:_ApplyChange(row.id, id)
			end,
		})
		table.insert(self._rows, dropdown)
	end
end

function SettingsScreen:GetState(): { [string]: any }
	return self._state
end

function SettingsScreen:_OnShow()
	-- Intro is driven centrally by UIScreenBase:Show (active animation pack).
end

return SettingsScreen

--!strict
-- Settings / options menu — rendered bar-for-bar through the EXACT reference skin
-- (Reference/RefSettings): a DARK, translucent RefSkin.Modal whose body is a
-- scroll of nested-box option rows. Unlike the reference (which hard-codes three
-- placeholder rows), this builds ONE row per SettingsConfig row, so the real
-- settings show, and every control is FUNCTIONAL against self._state:
--   * Toggle   -> the reference OFF/ON sliding knob
--   * Slider   -> a click/drag track with a green fill + value readout
--   * Dropdown -> a boxy button that cycles through the option list
-- Each control calls self:_ApplyChange(id, value), which updates state + fires the
-- injected onChange. Because the chrome is dark, WHITE text is correct throughout
-- (do not force dark text here — that rule is for LIGHT surfaces).
--
-- This is the "text-heavy menu pack" counterpart to the shop: same reference
-- primitive (RefSkin), different content, driven entirely by SettingsConfig. Add a
-- setting = add a row in SettingsConfig; no screen changes.

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local SettingsConfig = require(script.Parent.Parent.Config.SettingsConfig)
local UIScreenBase = require(script.Parent.UIScreenBase)
local RefSkin = require(script.Parent.Parent.Reference.RefSkin)

local C = RefSkin.C

-- Reference-exact secondary colours (measured off RefSettings).
local ROW_LIGHT = Color3.fromRGB(78, 108, 146)
local TRACK_TOP = Color3.fromRGB(150, 158, 168)
local TRACK_BOTTOM = Color3.fromRGB(120, 128, 138)
local TRACK_BORDER = Color3.fromRGB(96, 102, 112)
local TRACK_LIGHT = Color3.fromRGB(196, 202, 210)
local KNOB_ON_TOP = Color3.fromRGB(108, 214, 92)
local KNOB_ON_BOTTOM = Color3.fromRGB(72, 176, 56)
local KNOB_OFF_TOP = Color3.fromRGB(236, 86, 86)
local KNOB_LIGHT_ON = Color3.fromRGB(214, 244, 206)
local HANDLE_TOP = Color3.fromRGB(236, 240, 246)
local HANDLE_BOTTOM = Color3.fromRGB(196, 202, 210)

-- Fixed pixel geometry for the scrolling list (the reference's Scale rows only had
-- to cover three items; a data-driven list of ~a dozen scrolls instead).
local ROW_H = 60
local HEADER_H = 30
local LIST_PAD = 8

-- Per-kind row icon (the reference used per-row emoji; here the glyph signals the
-- control type so the list stays structurally consistent).
local KIND_ICON = {
	Toggle = "🔘",
	Slider = "🎚️",
	Dropdown = "🔻",
}

local SettingsScreen = setmetatable({}, { __index = UIScreenBase })
SettingsScreen.__index = SettingsScreen

function SettingsScreen.new()
	local self = UIScreenBase.new("SettingsScreen", 17)
	self._state = SettingsConfig.Defaults()
	self._rows = {}
	-- Global input connections (slider drag) tracked so a rebuild / teardown can
	-- disconnect them — UserInputService connections are not tied to any Instance.
	self._conns = {} :: { RBXScriptConnection }
	-- Optional injected callback: (id, value) -> () when a setting changes.
	self._onChange = nil :: ((string, any) -> ())?
	return setmetatable(self, SettingsScreen)
end

function SettingsScreen:SetChangeHandler(fn: (string, any) -> ())
	self._onChange = fn
end

function SettingsScreen:_Track(conn: RBXScriptConnection)
	table.insert(self._conns, conn)
end

-- ---- reference row shell ------------------------------------------------
-- A full-width nested box (dark border -> light gap -> gradient inner) with the
-- reference's icon + left-aligned option label. Returns the inner frame; controls
-- parent into it. `labelW` is how much horizontal room the label gets before the
-- control sits on the right.
local function settingRow(parent: Instance, icon: string, text: string, labelW: number, order: number): Frame
	local _, inner = RefSkin.box(parent, {
		size = UDim2.new(1, 0, 0, ROW_H), gradTop = C.SetRowTop, gradBottom = C.SetRowBottom,
		border = C.SetRowBorder, lightBg = ROW_LIGHT, gap = 4, zindex = 4,
	})
	inner.Parent.LayoutOrder = order
	RefSkin.label(inner, icon, {
		size = UDim2.fromScale(0.1, 0.6), position = UDim2.fromScale(0.035, 0.5), anchor = Vector2.new(0, 0.5),
		outline = 0, textSize = 34, zindex = 6,
	})
	RefSkin.label(inner, text, {
		size = UDim2.fromScale(labelW, 0.5), position = UDim2.fromScale(0.15, 0.5), anchor = Vector2.new(0, 0.5),
		align = Enum.TextXAlignment.Left, color = C.White, outline = 3, textSize = 30, zindex = 6,
	})
	return inner
end

function SettingsScreen:_BuildContent()
	-- Dark, translucent modal shell — the EXACT RefSettings.build shape/flags.
	local modal = RefSkin.Modal({
		parent = self.Root,
		title = self:_R("settings.title"),
		aspect = 1.62,
		widthScale = 0.5,
		dark = true,
		transparency = 0.15,
		onClose = function()
			self.ScreenController:HideScreen("settings")
		end,
	})
	self._modal = modal

	-- Body scroll (the reference body only held 3 Scale rows; a data-driven list
	-- needs to scroll). RefSkin.scroll gives the reference scrollbar colour; switch
	-- it to an automatic canvas so the list's own height drives it.
	local scroll = RefSkin.scroll(modal.body, 1)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	self._scroll = scroll

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = scroll

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Padding = UDim.new(0, LIST_PAD)
	layout.Parent = scroll

	self:_BuildRows()
end

function SettingsScreen:_BuildRows()
	for _, inst in self._rows do
		inst:Destroy()
	end
	table.clear(self._rows)
	for _, conn in self._conns do
		conn:Disconnect()
	end
	table.clear(self._conns)

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	for _, section in SettingsConfig.Sections do
		self:_SectionHeader(self:_R(section.titleKey), nextOrder())
		for _, row in section.rows do
			self:_BuildRow(row, nextOrder())
		end
	end
end

-- Dark chrome -> white section header (the base outline keeps it crisp).
function SettingsScreen:_SectionHeader(text: string, order: number)
	local holder = Instance.new("Frame")
	holder.Name = "SectionHeader"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.new(1, 0, 0, HEADER_H)
	holder.LayoutOrder = order
	holder.ZIndex = 4
	holder.Parent = self._scroll
	RefSkin.label(holder, text, {
		size = UDim2.fromScale(0.7, 0.8), position = UDim2.fromScale(0.01, 0.5), anchor = Vector2.new(0, 0.5),
		align = Enum.TextXAlignment.Left, color = C.Gold, outline = 3, textSize = 26, zindex = 5,
	})
	table.insert(self._rows, holder)
end

function SettingsScreen:_ApplyChange(id: string, value: any)
	self._state[id] = value
	if self._onChange then
		self._onChange(id, value)
	end
end

function SettingsScreen:_BuildRow(row: any, order: number)
	local value = self._state[row.id]
	local icon = KIND_ICON[row.kind] or "•"
	if row.kind == "Toggle" then
		local inner = settingRow(self._scroll, icon, self:_R(row.labelKey), 0.5, order)
		self:_ToggleControl(inner, value == true, function(v: boolean)
			self:_ApplyChange(row.id, v)
		end)
		table.insert(self._rows, inner.Parent)
	elseif row.kind == "Slider" then
		local inner = settingRow(self._scroll, icon, self:_R(row.labelKey), 0.4, order)
		self:_SliderControl(inner, row, tonumber(value) or row.min or 0, function(v: number)
			self:_ApplyChange(row.id, v)
		end)
		table.insert(self._rows, inner.Parent)
	elseif row.kind == "Dropdown" then
		local inner = settingRow(self._scroll, icon, self:_R(row.labelKey), 0.45, order)
		local options = {}
		for _, opt in row.options do
			table.insert(options, { id = opt.id, text = self:_R(opt.textKey) })
		end
		self:_DropdownControl(inner, options, value, function(id: string)
			self:_ApplyChange(row.id, id)
		end)
		table.insert(self._rows, inner.Parent)
	end
end

-- ---- Toggle: the reference OFF/ON sliding knob (RefSettings.toggleControl) -----
function SettingsScreen:_ToggleControl(row: Frame, initial: boolean, onChanged: (boolean) -> ())
	local _, track = RefSkin.box(row, {
		size = UDim2.fromScale(0.3, 0.62), position = UDim2.fromScale(0.97, 0.5), anchor = Vector2.new(1, 0.5),
		gradTop = TRACK_TOP, gradBottom = TRACK_BOTTOM, border = TRACK_BORDER, lightBg = TRACK_LIGHT, gap = 3, zindex = 5,
	})

	local knobOuter, knobInner = RefSkin.box(track, {
		button = true, size = UDim2.fromScale(0.46, 0.84), anchor = Vector2.new(0.5, 0.5),
		position = initial and UDim2.fromScale(0.73, 0.5) or UDim2.fromScale(0.27, 0.5),
		gradTop = initial and KNOB_ON_TOP or KNOB_OFF_TOP, gradBottom = initial and KNOB_ON_BOTTOM or C.Red,
		border = C.RedDark, lightBg = initial and KNOB_LIGHT_ON or Color3.fromRGB(252, 214, 214), gap = 2, zindex = 6,
	})
	local lbl = RefSkin.label(knobInner, initial and "ON" or "OFF", { color = C.White, outline = 2.5, textSize = 22, zindex = 8 })
	local grad = knobInner:FindFirstChildOfClass("UIGradient")

	local on = initial
	self:_Track((knobOuter :: TextButton).Activated:Connect(function()
		on = not on
		TweenService:Create(knobOuter, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = on and UDim2.fromScale(0.73, 0.5) or UDim2.fromScale(0.27, 0.5),
		}):Play()
		if grad then
			grad.Color = on and ColorSequence.new(KNOB_ON_TOP, KNOB_ON_BOTTOM)
				or ColorSequence.new(KNOB_OFF_TOP, C.Red)
		end
		lbl.Text = on and "ON" or "OFF"
		onChanged(on)
	end))
end

-- ---- Slider: click/drag track with a green fill + numeric readout -------------
function SettingsScreen:_SliderControl(row: Frame, spec: any, initial: number, onChanged: (number) -> ())
	local min = spec.min or 0
	local max = spec.max or 100
	local step = spec.step or 1
	local decimals = spec.decimals or 0
	local span = (max - min)
	if span == 0 then
		span = 1
	end
	local fmt = "%." .. tostring(decimals) .. "f"

	-- Value readout, far right (white on the dark row — legible).
	local valueLabel = RefSkin.label(row, string.format(fmt, initial), {
		size = UDim2.fromScale(0.12, 0.5), position = UDim2.fromScale(0.985, 0.5), anchor = Vector2.new(1, 0.5),
		align = Enum.TextXAlignment.Right, color = C.White, outline = 2.5, textSize = 26, zindex = 6,
	})

	-- The track is a clickable box; clicking/dragging anywhere on it sets the value.
	local trackOuter, trackInner = RefSkin.box(row, {
		button = true, size = UDim2.fromScale(0.3, 0.34), position = UDim2.fromScale(0.84, 0.5), anchor = Vector2.new(1, 0.5),
		gradTop = TRACK_TOP, gradBottom = TRACK_BOTTOM, border = TRACK_BORDER, lightBg = TRACK_LIGHT, gap = 3, zindex = 5,
	})

	-- Green fill grows from the left edge of the track inner.
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.AnchorPoint = Vector2.new(0, 0.5)
	fill.Position = UDim2.fromScale(0, 0.5)
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 7
	RefSkin.gradientFill(fill, C.GreenTop, C.GreenBottom)
	fill.Parent = trackInner

	-- A chunky thumb that sticks proud of the track for grabbing.
	local handleOuter = RefSkin.box(trackInner, {
		size = UDim2.new(0, 14, 1.5, 0), anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0, 0.5),
		gradTop = HANDLE_TOP, gradBottom = HANDLE_BOTTOM, border = C.Outline, lightBg = C.White, gap = 2, zindex = 8,
	})

	local function quantize(raw: number): number
		local snapped = min + math.floor((raw - min) / step + 0.5) * step
		return math.clamp(snapped, min, max)
	end

	local function render(value: number)
		local frac = (value - min) / span
		fill.Size = UDim2.fromScale(frac, 1)
		handleOuter.Position = UDim2.fromScale(frac, 0.5)
		valueLabel.Text = string.format(fmt, value)
	end
	render(quantize(initial))

	local dragging = false
	local function applyFromX(x: number)
		local absPos = trackInner.AbsolutePosition.X
		local absW = trackInner.AbsoluteSize.X
		if absW <= 0 then
			return
		end
		local frac = math.clamp((x - absPos) / absW, 0, 1)
		local value = quantize(min + frac * span)
		render(value)
		onChanged(value)
	end

	self:_Track(trackOuter.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			applyFromX(input.Position.X)
		end
	end))
	self:_Track(UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			applyFromX(input.Position.X)
		end
	end))
	self:_Track(UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
end

-- ---- Dropdown: boxy button that CYCLES the option list -----------------------
-- The whole reference surface (modal body, scroll, every row inner) clips its
-- descendants, so an expanding overlay list would be cut off. Cycling the current
-- option on click is fully functional, self-contained, and stays on-style with the
-- reference buttonControl.
function SettingsScreen:_DropdownControl(row: Frame, options: { { id: string, text: string } }, initialId: any, onChanged: (string) -> ())
	local idx = 1
	for i, opt in options do
		if opt.id == initialId then
			idx = i
			break
		end
	end

	local outer, inner = RefSkin.box(row, {
		button = true, size = UDim2.fromScale(0.34, 0.62), position = UDim2.fromScale(0.97, 0.5), anchor = Vector2.new(1, 0.5),
		gradTop = C.GrayTop, gradBottom = C.GrayBottom, border = C.GrayBottom, lightBg = Color3.fromRGB(214, 220, 228), gap = 3, zindex = 5,
	})
	local lbl = RefSkin.label(inner, options[idx] and options[idx].text or "", {
		size = UDim2.fromScale(0.74, 0.6), position = UDim2.fromScale(0.06, 0.5), anchor = Vector2.new(0, 0.5),
		align = Enum.TextXAlignment.Left, color = C.White, outline = 2.5, textSize = 24, zindex = 7,
	})
	-- Cycle affordance on the right edge.
	RefSkin.label(inner, "▸", {
		size = UDim2.fromScale(0.16, 0.6), position = UDim2.fromScale(0.97, 0.5), anchor = Vector2.new(1, 0.5),
		color = C.White, outline = 2, textSize = 22, zindex = 7,
	})

	self:_Track((outer :: TextButton).Activated:Connect(function()
		if #options == 0 then
			return
		end
		idx = (idx % #options) + 1
		lbl.Text = options[idx].text
		onChanged(options[idx].id)
	end))
end

function SettingsScreen:GetState(): { [string]: any }
	return self._state
end

function SettingsScreen:_OnShow()
	-- No animated panel is registered (the shell is a RefSkin.Modal, not a
	-- UIPanelComponent); the base fades the Root in on Show.
end

function SettingsScreen:Destroy()
	for _, conn in self._conns do
		conn:Disconnect()
	end
	table.clear(self._conns)
	UIScreenBase.Destroy(self)
end

return SettingsScreen

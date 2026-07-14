--!strict
-- Always-on HUD, rebuilt as a bar-for-bar reproduction of Reference/RefHUD via
-- the RefSkin primitive (dark border -> light gap -> gradient inner -> content).
-- The persistent layout (tabs, readouts, counters, icon rail, side deals) uses
-- RefHUD's EXACT sizes / positions / gradients / text sizes / outlines; only the
-- placeholder TEXT is swapped for live data:
--   * the two counters (➕ / 💾) show live coins & gems from self._values
--   * the two readouts (🏰 / 📡) show live wave & timer
--   * the left icon rail (🧺 / 📖 / ⚙️) opens Store / Index / Settings
--
-- Transient UI is unchanged: PushToast/PushBanner still drive the toast stack and
-- the top-center banner via UIToastComponent / UINotificationComponent. Values
-- update in place via Update({ values = ... }); Update({ objectives = ... }) still
-- renders a small boxed list without crashing.

local UIStyler = require(script.Parent.Parent.UIStyler)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local HUDConfig = require(script.Parent.Parent.Config.HUDConfig)
local UIScreenBase = require(script.Parent.UIScreenBase)
local UIToastComponent = require(script.Parent.Parent.Components.UIToastComponent)
local UINotificationComponent = require(script.Parent.Parent.Components.UINotificationComponent)
local RefSkin = require(script.Parent.Parent.Reference.RefSkin)

local C = RefSkin.C
-- Light frame colour in the nested-box gap (RefHUD's exact LIGHT).
local LIGHT = Color3.fromRGB(246, 249, 254)

local GameHUDScreen = setmetatable({}, { __index = UIScreenBase })
GameHUDScreen.__index = GameHUDScreen

-- ---- RefHUD primitives (ported verbatim from Reference/RefHUD) ---------

local function squareBox(box: GuiObject)
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = box
end

-- Renders a HUD glyph filling `parent`: an uploaded image asset (rbxassetid://…)
-- becomes a RefSkin.icon; anything else (a bare emoji with no asset, e.g. 📖 / 🔨)
-- stays a RefSkin.label. `textSize` only applies to the emoji fallback.
local function glyph(parent: Instance, id: string, textSize: number): GuiObject
	if id:match("^rbxassetid://") then
		return RefSkin.icon(parent, id, { zindex = 5 })
	end
	return RefSkin.label(parent, id, { outline = 0, textSize = textSize, zindex = 5 })
end

local function tabButton(root: Instance, size: UDim2, pos: UDim2, anchor: Vector2, gTop: Color3, gBottom: Color3, border: Color3, text: string, textSize: number, onClick: (() -> ())?)
	local box, inner = RefSkin.box(root, {
		button = true, size = size, position = pos, anchor = anchor,
		gradTop = gTop, gradBottom = gBottom, border = border, lightBg = LIGHT, studs = false, gap = 5, zindex = 2,
	})
	RefSkin.label(inner, text, { color = C.White, outline = 2.5, textSize = textSize, zindex = 5 })
	if onClick then
		(box :: TextButton).Activated:Connect(onClick)
	end
end

local function iconButton(root: Instance, pos: UDim2, anchor: Vector2, icon: string, label: string, gTop: Color3, gBottom: Color3, border: Color3, onClick: (() -> ())?)
	local holder = UIStyler.Frame("IconBtn")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(0.075, 0.16)
	holder.Position = pos
	holder.AnchorPoint = anchor
	holder.Parent = root

	local box, inner = RefSkin.box(holder, {
		button = true, size = UDim2.fromScale(1, 0.74), position = UDim2.fromScale(0.5, 0), anchor = Vector2.new(0.5, 0),
		gradTop = gTop, gradBottom = gBottom, border = border, lightBg = LIGHT, studs = false, gap = 5, zindex = 2,
	})
	squareBox(box)
	glyph(inner, icon, 52)

	RefSkin.label(holder, label, {
		size = UDim2.fromScale(1.3, 0.24), position = UDim2.fromScale(0.5, 0.78), anchor = Vector2.new(0.5, 0),
		color = C.White, outline = 3, textSize = 24, zindex = 5,
	})

	if onClick then
		(box :: TextButton).Activated:Connect(onClick)
	end
end

-- Returns the VALUE label so the caller can wire it to live data.
local function readout(root: Instance, pos: UDim2, title: string, value: string, valueColor: Color3, icon: string): TextLabel
	local holder = UIStyler.Frame("Readout")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(0.2, 0.16)
	holder.Position = pos
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Parent = root
	RefSkin.label(holder, title .. " " .. icon, {
		size = UDim2.fromScale(1, 0.42), position = UDim2.fromScale(0.5, 0), anchor = Vector2.new(0.5, 0),
		color = C.White, outline = 3, textSize = 26, zindex = 5,
	})
	return RefSkin.label(holder, value, {
		size = UDim2.fromScale(1, 0.5), position = UDim2.fromScale(0.5, 0.46), anchor = Vector2.new(0.5, 0),
		color = valueColor, outline = 3.5, textSize = 40, zindex = 5,
	})
end

-- Returns (valueLabel, holder). holder is used as a highlight anchor.
local function counter(root: Instance, pos: UDim2, badge: string, value: string, bTop: Color3, bBottom: Color3): (TextLabel, Frame)
	local holder = UIStyler.Frame("Counter")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(0.14, 0.075)
	holder.Position = pos
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Parent = root

	local box, inner = RefSkin.box(holder, {
		size = UDim2.fromScale(0.38, 1), position = UDim2.fromScale(0, 0.5), anchor = Vector2.new(0, 0.5),
		gradTop = bTop, gradBottom = bBottom, border = C.Outline, lightBg = LIGHT, studs = false, gap = 4, zindex = 2,
	})
	squareBox(box)
	glyph(inner, badge, 34)

	local valueLabel = RefSkin.label(holder, value, {
		size = UDim2.fromScale(0.58, 0.86), position = UDim2.fromScale(0.42, 0.5), anchor = Vector2.new(0, 0.5),
		align = Enum.TextXAlignment.Left, color = C.White, outline = 3.5, textSize = 40, zindex = 5,
	})
	return valueLabel, holder
end

local function sideDeal(root: Instance, pos: UDim2, icon: string, price: string)
	local holder = UIStyler.Frame("Deal")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(0.08, 0.22)
	holder.Position = pos
	holder.AnchorPoint = Vector2.new(1, 0.5)
	holder.Parent = root
	RefSkin.label(holder, "Deal", {
		size = UDim2.fromScale(1.1, 0.18), position = UDim2.fromScale(0.5, 0), anchor = Vector2.new(0.5, 0),
		color = C.White, outline = 3, textSize = 22, zindex = 5,
	})
	local _, artInner = RefSkin.box(holder, {
		size = UDim2.fromScale(0.9, 0.5), position = UDim2.fromScale(0.5, 0.22), anchor = Vector2.new(0.5, 0),
		gradTop = C.Blue, gradBottom = C.BlueDark, border = C.Outline, lightBg = LIGHT, gap = 4, zindex = 2,
	})
	glyph(artInner, icon, 40)

	local _, priceInner = RefSkin.box(holder, {
		size = UDim2.fromScale(0.85, 0.2), position = UDim2.fromScale(0.5, 1), anchor = Vector2.new(0.5, 1),
		gradTop = C.GreenTop, gradBottom = C.GreenBottom, border = C.GreenBorder, lightBg = LIGHT, studs = false, gap = 3, zindex = 2,
	})
	-- Price row: the number as text + a Robux icon beside it. (An image can't live
	-- inside the text, so the "⬡" glyph is replaced by a real icon laid out in a row.)
	local priceRow = Instance.new("UIListLayout")
	priceRow.FillDirection = Enum.FillDirection.Horizontal
	priceRow.VerticalAlignment = Enum.VerticalAlignment.Center
	priceRow.HorizontalAlignment = Enum.HorizontalAlignment.Center
	priceRow.SortOrder = Enum.SortOrder.LayoutOrder
	priceRow.Padding = UDim.new(0, 3)
	priceRow.Parent = priceInner

	local priceText = Instance.new("TextLabel")
	priceText.Name = "Price"
	priceText.BackgroundTransparency = 1
	priceText.BorderSizePixel = 0
	priceText.AutomaticSize = Enum.AutomaticSize.X
	priceText.Size = UDim2.fromScale(0, 0.86)
	priceText.Text = price
	priceText.FontFace = RefSkin.Font
	priceText.TextColor3 = C.White
	priceText.TextSize = 22
	priceText.TextXAlignment = Enum.TextXAlignment.Center
	priceText.TextYAlignment = Enum.TextYAlignment.Center
	priceText.LayoutOrder = 1
	priceText.ZIndex = 5
	RefSkin.outline(priceText, C.Outline, 2.5)
	priceText.Parent = priceInner

	RefSkin.icon(priceInner, RefSkin.Assets.robux, {
		size = UDim2.fromScale(0.5, 0.8),
		zindex = 5,
		layoutOrder = 2,
	})
end

-- ---- lifecycle --------------------------------------------------------

function GameHUDScreen.new()
	local self = UIScreenBase.new("GameHUDScreen", 2)
	self._values = table.clone(HUDConfig.DefaultValues)
	self._objectives = {}
	self._toasts = {}
	-- Live value labels, keyed by HUDConfig value id (filled in _BuildContent).
	self._valueLabels = {} :: { [string]: TextLabel }
	-- Persisted so ApplyLayout can still tune the HUD scale (see _ApplyPackScale).
	self._scaleOverride = nil :: number?
	return setmetatable(self, GameHUDScreen)
end

-- Tear down and rebuild HUD content (used on a pack change at runtime).
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
	self._objectives = {}
	self._toasts = {}
	self._valueLabels = {}
	self._banner = nil
	self:_BuildContent()
	self:_RefreshValues()
end

function GameHUDScreen:_BuildContent()
	-- A UIScale so a pack (or a layout preset via ApplyLayout) can scale the whole
	-- HUD up/down without touching any of the fixed RefHUD fractions below.
	local scale = Instance.new("UIScale")
	scale.Parent = self.Root
	self._scale = scale

	-- ---- persistent RefHUD layout (EXACT reproduction) ----------------
	local root = self.Root

	tabButton(root, UDim2.fromScale(0.2, 0.06), UDim2.fromScale(0.34, 0.02), Vector2.new(1, 0),
		Color3.fromRGB(74, 150, 240), Color3.fromRGB(40, 110, 210), Color3.fromRGB(24, 78, 168), "Shop", 26, function()
			self.ScreenController:ShowScreen("shop")
		end)
	tabButton(root, UDim2.fromScale(0.16, 0.08), UDim2.fromScale(0.5, 0.015), Vector2.new(0.5, 0),
		Color3.fromRGB(255, 190, 70), Color3.fromRGB(238, 150, 30), Color3.fromRGB(170, 96, 16), "My Plot", 34)
	tabButton(root, UDim2.fromScale(0.14, 0.06), UDim2.fromScale(0.66, 0.02), Vector2.new(0, 0),
		C.GreenTop, C.GreenBottom, C.GreenBorder, "Sell", 30)

	-- Readouts (wave / timer) — exact RefHUD icons kept; value wired to live data.
	self._valueLabels.wave = readout(root, UDim2.fromScale(0.43, 0.16), "Wave", "0000", Color3.fromRGB(120, 232, 110), "🏰")
	self._valueLabels.timer = readout(root, UDim2.fromScale(0.6, 0.16), "Time", "0000", Color3.fromRGB(196, 130, 250), "📡")

	-- Counters (coins / gems) — exact RefHUD badges kept; value wired to live data.
	local coinsLabel, coinsHolder = counter(root, UDim2.fromScale(0.02, 0.34), RefSkin.Assets.cash, "0000", Color3.fromRGB(255, 208, 92), Color3.fromRGB(236, 170, 40))
	self._valueLabels.coins = coinsLabel
	local gemsLabel = counter(root, UDim2.fromScale(0.02, 0.43), RefSkin.Assets.purpleGem, "0000", Color3.fromRGB(214, 128, 214), Color3.fromRGB(168, 78, 168))
	self._valueLabels.gems = gemsLabel

	-- Tutorial's "welcome" step highlights this anchor; point it at the coins chip.
	self.ScreenController:RegisterHighlightTarget("hud.topRight", coinsHolder)

	-- Left icon rail — wired to the Store / Index / Settings screens.
	iconButton(root, UDim2.fromScale(0.03, 0.56), Vector2.new(0, 0), RefSkin.Assets.cart, "Store",
		Color3.fromRGB(238, 96, 96), Color3.fromRGB(206, 48, 48), C.RedDark, function()
			self.ScreenController:ShowScreen("store")
		end)
	iconButton(root, UDim2.fromScale(0.03, 0.72), Vector2.new(0, 0), "📖", "Index",
		Color3.fromRGB(120, 168, 232), Color3.fromRGB(70, 120, 200), Color3.fromRGB(28, 78, 168), function()
			self.ScreenController:ShowScreen("index")
		end)
	iconButton(root, UDim2.fromScale(0.03, 0.88), Vector2.new(0, 0), RefSkin.Assets.settings, "Settings",
		Color3.fromRGB(120, 168, 232), Color3.fromRGB(70, 120, 200), Color3.fromRGB(28, 78, 168), function()
			self.ScreenController:ShowScreen("settings")
		end)

	-- Right icon rail (reference placeholders — no wiring specified).
	iconButton(root, UDim2.fromScale(0.965, 0.6), Vector2.new(1, 0), "🔨", "Label",
		Color3.fromRGB(120, 168, 232), Color3.fromRGB(70, 120, 200), Color3.fromRGB(28, 78, 168))
	iconButton(root, UDim2.fromScale(0.965, 0.78), Vector2.new(1, 0), RefSkin.Assets.wrong, "Label",
		Color3.fromRGB(238, 96, 96), Color3.fromRGB(206, 48, 48), C.RedDark)

	sideDeal(root, UDim2.fromScale(0.99, 0.2), RefSkin.Assets.blueGem, "00")
	sideDeal(root, UDim2.fromScale(0.99, 0.42), RefSkin.Assets.gift, "00")

	-- ---- transient-UI holders (unchanged) -----------------------------

	-- Objectives holder (lower-left). RefHUD has no objectives, so this stays empty
	-- unless Update({ objectives = ... }) is called; kept so that path never crashes.
	local objectives = UIStyler.Frame("Objectives")
	objectives.BackgroundTransparency = 1
	objectives.AnchorPoint = Vector2.new(0, 1)
	objectives.Position = UDim2.fromScale(0.13, 0.52)
	objectives.Size = UDim2.fromScale(0.22, 0)
	objectives.AutomaticSize = Enum.AutomaticSize.Y
	UIStyler.ListLayout({ Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Left }).Parent = objectives
	objectives.Parent = root
	self._objectivesHolder = objectives

	-- Toast stack (bottom-right).
	local toastStack = UIStyler.Frame("Toasts")
	toastStack.BackgroundTransparency = 1
	toastStack.AnchorPoint = Vector2.new(1, 1)
	toastStack.Position = UDim2.fromScale(1 - 0.02, 1 - 0.02)
	toastStack.Size = UDim2.fromScale(0.24, 0.34)
	UIStyler.ListLayout({
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	}).Parent = toastStack
	toastStack.Parent = root
	self._toastStack = toastStack

	-- Banner slot (top-center, below the top HUD row).
	local bannerSlot = UIStyler.Frame("Banner")
	bannerSlot.BackgroundTransparency = 1
	bannerSlot.AnchorPoint = Vector2.new(0.5, 0)
	bannerSlot.Position = UDim2.fromScale(0.5, 0.28)
	bannerSlot.Size = UDim2.fromScale(0.29, 0.1)
	bannerSlot.Parent = root
	self._bannerSlot = bannerSlot

	self:_ApplyPackScale()
end

-- ---- banner -----------------------------------------------------------

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
	if not data then
		return
	end
	if data.values then
		for id, value in data.values do
			self._values[id] = value
		end
		self:_RefreshValues()
	end
	if data.objectives then
		self:_RenderObjectives(data.objectives)
	end
end

function GameHUDScreen:_RefreshValues()
	local v = self._values
	for id, label in self._valueLabels do
		if label.Parent then
			local value = v[id] or 0
			-- Timer formats as M:SS; every other wired value is a plain integer.
			label.Text = id == "timer" and HUDConfig.FormatTime(value) or tostring(math.floor(value))
		end
	end
end

-- RefHUD has no objectives; render any pushed ones as a small boxed list so the
-- Update({ objectives }) path stays functional without crashing.
function GameHUDScreen:_RenderObjectives(objectives: any)
	if not self._objectivesHolder then
		return
	end
	for _, item in self._objectives do
		item:Destroy()
	end
	table.clear(self._objectives)
	for i, objective in objectives do
		local _, inner = RefSkin.box(self._objectivesHolder, {
			size = UDim2.new(1, 0, 0, 30), border = C.CardBorder, lightBg = LIGHT,
			gradTop = C.CardTop, gradBottom = C.CardBottom, gap = 3, zindex = 2,
		})
		inner.Parent.LayoutOrder = i
		RefSkin.label(inner, string.format(
			"%s %s",
			objective.done and "✅" or "⬜",
			TextConfig.Resolve(objective.textKey or objective.text)
		), {
			size = UDim2.fromScale(0.94, 0.7), position = UDim2.fromScale(0.03, 0.5), anchor = Vector2.new(0, 0.5),
			align = Enum.TextXAlignment.Left, color = C.Ink, outline = 0, textSize = 20, zindex = 5,
		})
		table.insert(self._objectives, inner.Parent)
	end
end

-- ---- layout / scale hooks (public API preserved) ----------------------

-- The RefHUD layout is fixed, so per-element region moves are a no-op now; the
-- method is kept so ClientHandler's SetElementRegion binding + the UIDebug seam
-- don't error. A scale override (from ApplyLayout) is still honoured.
function GameHUDScreen:SetElementRegion(_elementId: string, _region: string) end

-- Apply a layout preset's HUD block. Region/money placement is fixed in this
-- reproduction, so only the optional scale override is applied (kept so
-- UILayoutController:Apply and its bindings keep working).
function GameHUDScreen:ApplyLayout(opts: { money: string?, regions: { [string]: string }?, scaleOverride: number? })
	self._scaleOverride = opts.scaleOverride
	self:_ApplyPackScale()
end

function GameHUDScreen:_ApplyPackScale()
	local pack = self.ThemeController:GetPack()
	if self._scale then
		self._scale.Scale = self._scaleOverride or pack.HUD.Scale
	end
end

function GameHUDScreen:_OnShow()
	self:_RefreshValues()
	self:_ApplyPackScale()
end

return GameHUDScreen

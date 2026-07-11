--!strict
-- The runtime theme/pack auditioner AND full live theme editor.
--
-- Left column : swatch buttons for every registered theme + pack, applied on
--               click so the whole UI re-skins live. Built once.
-- Right column: an editor that edits a working copy of the current theme —
--               color fields for every token, plus sliders for radii, spacing,
--               animation time and effect scales — over an action bar with
--               Export / Import / Reset. Every change calls
--               UIThemeController:ApplyThemeObject so the preview updates live.
--
-- Export : serializes the working theme to a drop-in .luau module via
--          ThemeSerializer, copies it to the clipboard where possible, and
--          shows it in a selectable box for manual copy / pasting to a dev.
-- Import : parses a pasted module back into a theme and applies it.
--
-- Gated by DevConfig so it never ships to live players by accident.

local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local ThemeSerializer = require(script.Parent.Parent.Themes.ThemeSerializer)
local PackExporter = require(script.Parent.Parent.PackExporter)
local LayoutPresetConfig = require(script.Parent.Parent.Config.LayoutPresetConfig)
local PanelAnimConfig = require(script.Parent.Parent.Config.PanelAnimConfig)
local UIScreenBase = require(script.Parent.UIScreenBase)
local UIPanelComponent = require(script.Parent.Parent.Components.UIPanelComponent)
local UIButtonComponent = require(script.Parent.Parent.Components.UIButtonComponent)
local UISliderComponent = require(script.Parent.Parent.Components.UISliderComponent)
local UIColorFieldComponent = require(script.Parent.Parent.Components.UIColorFieldComponent)

local ThemeSelectorScreen = setmetatable({}, { __index = UIScreenBase })
ThemeSelectorScreen.__index = ThemeSelectorScreen

local COLOR_TOKENS = {
	"Primary", "Secondary", "Accent", "Background", "Surface", "SurfaceRaised",
	"Success", "Warning", "Error", "TextPrimary", "TextSecondary", "TextOnPrimary",
	"Stroke", "Overlay", "Disabled",
}

-- {label, category, key, min, max, step}
local NUMERIC_TOKENS = {
	{ "Radius: Small", "Radii", "Small", 0, 32, 1 },
	{ "Radius: Medium", "Radii", "Medium", 0, 40, 1 },
	{ "Radius: Large", "Radii", "Large", 0, 48, 1 },
	{ "Spacing: S", "Spacing", "S", 0, 24, 1 },
	{ "Spacing: M", "Spacing", "M", 0, 32, 1 },
	{ "Spacing: L", "Spacing", "L", 0, 40, 1 },
	{ "Hover Scale", "Effects", "HoverScale", 1, 1.2, 0.01 },
	{ "Press Scale", "Effects", "PressScale", 0.8, 1, 0.01 },
	{ "Stroke Thickness", "Effects", "StrokeThickness", 0, 6, 0.5 },
	{ "Gradient Intensity", "Effects", "GradientIntensity", 0, 0.4, 0.01 },
	{ "Shadow Transparency", "Effects", "ShadowTransparency", 0, 1, 0.05 },
	{ "Appear Time", "AnimAppear", "Time", 0.05, 1, 0.01 },
	{ "Swap Time", "AnimThemeSwap", "Time", 0.05, 1, 0.01 },
}

function ThemeSelectorScreen.new()
	local self = UIScreenBase.new("ThemeSelectorScreen", 18)
	self._working = nil :: Types.UITheme?
	self._colorFields = {}
	self._sliders = {}
	self._themeButtons = {}
	self._staticBuilt = false
	-- Injected by ClientHandler via SetDevTools: the layout-preset controller and
	-- the Test All runner. nil-safe so the editor still works without them.
	self._layoutController = nil :: any
	self._runTestAll = nil :: (() -> ())?
	return setmetatable(self, ThemeSelectorScreen)
end

-- ClientHandler injects the runtime dev tools the editor's buttons drive.
function ThemeSelectorScreen:SetDevTools(layoutController: any, runTestAll: () -> ())
	self._layoutController = layoutController
	self._runTestAll = runTestAll
end

local function cloneTheme(theme: Types.UITheme): Types.UITheme
	local copy: any = table.clone(theme :: any)
	for _, field in { "Colors", "Fonts", "TextSizes", "Radii", "Spacing", "Animations", "Effects" } do
		copy[field] = table.clone((theme :: any)[field])
	end
	return copy
end

function ThemeSelectorScreen:_BuildContent()
	local backdrop = UIStyler.Frame("Backdrop")
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.Parent = self.Root

	local panel = UIPanelComponent.new()
	self._panel = panel
	self:_SetAnimatedPanel(panel)
	panel:Create(self.Root, {
		titleKey = "theme.editor.title",
		size = UDim2.fromScale(0.62, 0.82),
		onClose = function()
			self.ScreenController:HideScreen("themeSelector")
		end,
	})

	-- ---- left column: theme + pack pickers (built once) ----------------
	local left = UIStyler.Frame("Left")
	left.BackgroundTransparency = 1
	left.Size = UDim2.new(0.32, -6, 1, -12)
	left.Position = UDim2.fromOffset(8, 8)
	left.Parent = panel.Body

	local leftScroll = Instance.new("ScrollingFrame")
	leftScroll.BackgroundTransparency = 1
	leftScroll.BorderSizePixel = 0
	leftScroll.Size = UDim2.fromScale(1, 1)
	leftScroll.CanvasSize = UDim2.new()
	leftScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	leftScroll.ScrollBarThickness = 5
	UIStyler.ListLayout({ Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }).Parent = leftScroll
	leftScroll.Parent = left
	self._leftScroll = leftScroll

	-- Dev tools (top of the column): live layout-preset picker + Test All.
	self:_ScreenLabel(leftScroll, "🛠️ Dev Tools", "Accent", "Subtitle", -20)
	self._layoutButton = UIButtonComponent.new()
	self._layoutButton:Create(leftScroll, {
		text = "Layout Presets", icon = "🧩", variant = "Secondary",
		size = UDim2.new(1, -6, 0, 42), layoutOrder = -19,
		onClick = function()
			self:_OpenLayoutPicker()
		end,
	})
	self._animButton = UIButtonComponent.new()
	self._animButton:Create(leftScroll, {
		text = "Open/Close Animation", icon = "🎞️", variant = "Secondary",
		size = UDim2.new(1, -6, 0, 42), layoutOrder = -18.5,
		onClick = function()
			self:_OpenAnimPicker()
		end,
	})
	self._testAllButton = UIButtonComponent.new()
	self._testAllButton:Create(leftScroll, {
		text = "Test All", icon = "🧪", variant = "Accent",
		size = UDim2.new(1, -6, 0, 42), layoutOrder = -18,
		onClick = function()
			if self._runTestAll then
				self._runTestAll()
			end
		end,
	})

	self:_ScreenLabel(leftScroll, self:_R("theme.selector.title"), "Accent", "Subtitle", 0)
	for i, theme in self.ThemeController:GetThemeList() do
		local button = UIButtonComponent.new()
		button:Create(leftScroll, {
			text = theme.DisplayName,
			icon = "🎨",
			variant = "Ghost",
			size = UDim2.new(1, -6, 0, 42),
			layoutOrder = i,
			onClick = function()
				self.ThemeController:SetTheme(theme.Id)
				self:_LoadWorking(self.ThemeController:GetTheme(), false)
			end,
		})
		table.insert(self._themeButtons, button)
	end

	self:_ScreenLabel(leftScroll, "Layout Packs", "Accent", "Subtitle", 100)
	for i, pack in self.ThemeController:GetPackList() do
		local button = UIButtonComponent.new()
		button:Create(leftScroll, {
			text = pack.DisplayName,
			icon = "🧩",
			variant = "Ghost",
			size = UDim2.new(1, -6, 0, 38),
			layoutOrder = 100 + i,
			onClick = function()
				self.ThemeController:SetPack(pack.Id)
				if self.ScreenController:IsVisible("shop") then
					-- Pack swap changes the layout shape (columns/spec), not just data.
					self.ScreenController:GetScreen("shop"):_RebuildLayout()
				end
			end,
		})
	end

	-- ---- right column: editor + action bar (controls rebuilt per show) -
	local right = UIStyler.Frame("Right")
	right.BackgroundTransparency = 1
	right.Size = UDim2.new(0.68, -14, 1, -12)
	right.Position = UDim2.new(0.32, 6, 0, 8)
	right.Parent = panel.Body

	local editorScroll = Instance.new("ScrollingFrame")
	editorScroll.BackgroundTransparency = 1
	editorScroll.BorderSizePixel = 0
	editorScroll.Size = UDim2.new(1, 0, 1, -56)
	editorScroll.CanvasSize = UDim2.new()
	editorScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	editorScroll.ScrollBarThickness = 6
	UIStyler.ListLayout({ Padding = UDim.new(0, 6) }).Parent = editorScroll
	editorScroll.Parent = right
	self._editorScroll = editorScroll

	local actionBar = UIStyler.Frame("Actions")
	actionBar.BackgroundTransparency = 1
	actionBar.Size = UDim2.new(1, 0, 0, 46)
	actionBar.AnchorPoint = Vector2.new(0, 1)
	actionBar.Position = UDim2.fromScale(0, 1)
	UIStyler.ListLayout({
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
	}).Parent = actionBar
	actionBar.Parent = right

	-- Scale-sized so all four buttons always fit the column with no overflow.
	self._exportButton = UIButtonComponent.new()
	self._exportButton:Create(actionBar, {
		textKey = "theme.export", icon = "📤", variant = "Primary",
		size = UDim2.new(0.25, -6, 1, 0), layoutOrder = 1,
		onClick = function() self:_Export() end,
	})
	-- Export a self-contained pack/part module for handoff to another AI or dev.
	self._exportScriptButton = UIButtonComponent.new()
	self._exportScriptButton:Create(actionBar, {
		textKey = "theme.export_script", icon = "📦", variant = "Accent",
		size = UDim2.new(0.25, -6, 1, 0), layoutOrder = 2,
		onClick = function() self:_ExportScript() end,
	})
	self._importButton = UIButtonComponent.new()
	self._importButton:Create(actionBar, {
		textKey = "theme.import", icon = "📥", variant = "Secondary",
		size = UDim2.new(0.25, -6, 1, 0), layoutOrder = 3,
		onClick = function() self:_Import() end,
	})
	self._resetButton = UIButtonComponent.new()
	self._resetButton:Create(actionBar, {
		textKey = "theme.reset", variant = "Ghost",
		size = UDim2.new(0.25, -6, 1, 0), layoutOrder = 4,
		onClick = function() self:_LoadWorking(self.ThemeController:GetTheme(), true) end,
	})

	self._staticBuilt = true
end

-- ---- editor controls --------------------------------------------------

function ThemeSelectorScreen:_LoadWorking(theme: Types.UITheme, apply: boolean)
	self._working = cloneTheme(theme)
	self._working.Id = "Custom"
	self._working.DisplayName = "Custom"

	for _, field in self._colorFields do
		field:Destroy()
	end
	table.clear(self._colorFields)
	for _, slider in self._sliders do
		slider:Destroy()
	end
	table.clear(self._sliders)
	-- Drop any leftover section labels from a previous load.
	for _, child in self._editorScroll:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	self:_ScreenLabel(self._editorScroll, "Colors", "Accent", "Subtitle", nextOrder())
	for _, token in COLOR_TOKENS do
		local field = UIColorFieldComponent.new()
		field:Create(self._editorScroll, {
			label = token,
			value = (self._working :: any).Colors[token],
			layoutOrder = nextOrder(),
			onChanged = function(color: Color3)
				(self._working :: any).Colors[token] = color
				self:_ApplyWorking()
			end,
		})
		table.insert(self._colorFields, field)
	end

	self:_ScreenLabel(self._editorScroll, "Shape, Motion & Effects", "Accent", "Subtitle", nextOrder())
	for _, spec in NUMERIC_TOKENS do
		local label, category, key, min, max, step = spec[1], spec[2], spec[3], spec[4], spec[5], spec[6]
		local slider = UISliderComponent.new()
		slider:Create(self._editorScroll, {
			label = label,
			min = min, max = max, step = step,
			value = self:_ReadNumeric(category, key),
			decimals = step < 1 and 2 or 0,
			layoutOrder = nextOrder(),
			onChanged = function(value: number)
				self:_WriteNumeric(category, key, value)
				self:_ApplyWorking()
			end,
		})
		table.insert(self._sliders, slider)
	end

	if apply then
		self:_ApplyWorking()
	end
end

function ThemeSelectorScreen:_ReadNumeric(category: string, key: string): number
	local working = self._working :: any
	if category == "AnimAppear" then
		return working.Animations.Appear.Time
	elseif category == "AnimThemeSwap" then
		return working.Animations.ThemeSwap.Time
	end
	return working[category][key]
end

function ThemeSelectorScreen:_WriteNumeric(category: string, key: string, value: number)
	local working = self._working :: any
	if category == "AnimAppear" then
		local t = working.Animations.Appear
		working.Animations.Appear = TweenInfo.new(value, t.EasingStyle, t.EasingDirection)
	elseif category == "AnimThemeSwap" then
		local t = working.Animations.ThemeSwap
		working.Animations.ThemeSwap = TweenInfo.new(value, t.EasingStyle, t.EasingDirection)
	else
		working[category][key] = value
	end
end

function ThemeSelectorScreen:_ApplyWorking()
	if self._working then
		self.ThemeController:ApplyThemeObject(self._working)
	end
end

-- ---- export / import --------------------------------------------------

function ThemeSelectorScreen:_Export()
	if not self._working then
		return
	end
	self:_EnsureOverlays()
	local source = ThemeSerializer.Serialize(self._working)
	self._exportBox.Text = source
	self._exportOverlay.Visible = true

	local copied = false
	local setclip = (rawget(getfenv(0), "setclipboard") or rawget(getfenv(0), "toclipboard")) :: any
	if typeof(setclip) == "function" then
		copied = pcall(setclip, source)
	end
	self._exportHint.Text = self:_R(copied and "theme.export.hint" or "theme.export.hint_manual")
	self._exportBox:CaptureFocus()
end

-- Export-as-Script: pick which part of the pack to export, then emit a
-- self-contained module for it into the source viewer (copied to clipboard too).
function ThemeSelectorScreen:_ExportScript()
	self:_EnsurePartPicker()
	self._partPicker.Visible = true
end

function ThemeSelectorScreen:_EmitPart(partId: string)
	self:_EnsureOverlays()
	local theme = self._working or self.ThemeController:GetTheme()
	local pack = self.ThemeController:GetPack()
	local source = PackExporter.Export(partId, theme, pack)
	self._exportBox.Text = source
	if self._partPicker then
		self._partPicker.Visible = false
	end
	self._exportOverlay.Visible = true

	local copied = false
	local setclip = (rawget(getfenv(0), "setclipboard") or rawget(getfenv(0), "toclipboard")) :: any
	if typeof(setclip) == "function" then
		copied = pcall(setclip, source)
	end
	self._exportHint.Text = copied
		and "Copied! Paste this whole module to another AI or into a new ModuleScript."
		or "Select all and copy this module — it's fully self-contained."
	self._exportBox:CaptureFocus()
end

-- Lazily build the part-picker overlay (a themed grid of part buttons).
function ThemeSelectorScreen:_EnsurePartPicker()
	if self._partPicker then
		return
	end
	local theme = self:GetTheme()
	local overlay = UIStyler.Frame("PartPicker")
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.Visible = false
	overlay.ZIndex = 60
	overlay.Parent = self.Root

	local card = UIStyler.Frame("Card")
	card.Size = UDim2.fromScale(0.42, 0.56)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.BackgroundColor3 = theme.Colors.Surface
	card.ZIndex = 61
	UIStyler.Corner(12).Parent = card
	UIStyler.Padding(14).Parent = card
	card.Parent = overlay

	local title = UIStyler.TextLabel("Title")
	title.Size = UDim2.new(1, -36, 0, 28)
	title.Text = "📦 Export as Script — pick a part"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.FontFace = theme.Fonts.Title
	title.TextSize = theme.TextSizes.Subtitle
	title.TextColor3 = theme.Colors.TextPrimary
	title.ZIndex = 62
	title.Parent = card

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, 0, 1, -40)
	list.Position = UDim2.fromOffset(0, 36)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.ZIndex = 62
	UIStyler.ListLayout({ Padding = UDim.new(0, 6) }).Parent = list
	list.Parent = card

	self._partButtons = {}
	for i, part in PackExporter.Parts do
		local button = UIButtonComponent.new()
		button:Create(list, {
			text = part.label,
			variant = part.id == "full" and "Primary" or "Ghost",
			size = UDim2.new(1, -6, 0, 40),
			layoutOrder = i,
			onClick = function()
				self:_EmitPart(part.id)
			end,
		})
		table.insert(self._partButtons, button)
	end

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromOffset(28, 28)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Text = "✖"
	-- Same LegacyArial bug as the button icon fix: never assigning FontFace left
	-- this glyph on the emoji/symbol-incapable engine default.
	close.FontFace = theme.Fonts.Button
	close.TextScaled = true
	close.BackgroundColor3 = theme.Colors.Error
	close.TextColor3 = theme.Colors.TextOnPrimary
	close.ZIndex = 63
	UIStyler.Corner(1000).Parent = close
	UIStyler.Padding(6).Parent = close
	close.Activated:Connect(function()
		overlay.Visible = false
	end)
	close.Parent = card

	self._partPicker = overlay
end

-- ---- layout presets ---------------------------------------------------

function ThemeSelectorScreen:_OpenLayoutPicker()
	if not self._layoutController then
		return
	end
	self:_EnsureLayoutPicker()
	self._layoutPicker.Visible = true
end

-- Lazily build the layout-preset picker overlay (a themed scrolling list of
-- preset buttons). Clicking one applies it live via the layout controller.
function ThemeSelectorScreen:_EnsureLayoutPicker()
	if self._layoutPicker then
		return
	end
	local theme = self:GetTheme()
	local overlay = UIStyler.Frame("LayoutPicker")
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.Visible = false
	overlay.ZIndex = 60
	overlay.Parent = self.Root

	local card = UIStyler.Frame("Card")
	card.Size = UDim2.fromScale(0.46, 0.66)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.BackgroundColor3 = theme.Colors.Surface
	card.ZIndex = 61
	UIStyler.Corner(12).Parent = card
	UIStyler.Padding(14).Parent = card
	card.Parent = overlay

	local title = UIStyler.TextLabel("Title")
	title.Size = UDim2.new(1, -36, 0, 28)
	title.Text = "🧩 Layout Presets — moves the nav rail + HUD"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.FontFace = theme.Fonts.Title
	title.TextSize = theme.TextSizes.Subtitle
	title.TextColor3 = theme.Colors.TextPrimary
	title.ZIndex = 62
	title.Parent = card

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, 0, 1, -40)
	list.Position = UDim2.fromOffset(0, 36)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.ZIndex = 62
	UIStyler.ListLayout({ Padding = UDim.new(0, 6) }).Parent = list
	list.Parent = card

	self._layoutButtons = {}
	for i, preset in LayoutPresetConfig.Presets do
		local button = UIButtonComponent.new()
		button:Create(list, {
			text = string.format("%s   %s", preset.displayName, preset.description),
			icon = preset.icon,
			variant = preset.id == LayoutPresetConfig.DefaultPresetId and "Primary" or "Ghost",
			size = UDim2.new(1, -6, 0, 44),
			layoutOrder = i,
			onClick = function()
				self._layoutController:Apply(preset.id)
				overlay.Visible = false
			end,
		})
		table.insert(self._layoutButtons, button)
	end

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromOffset(28, 28)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Text = "✖"
	-- Same LegacyArial bug as the button icon fix: never assigning FontFace left
	-- this glyph on the emoji/symbol-incapable engine default.
	close.FontFace = theme.Fonts.Button
	close.TextScaled = true
	close.BackgroundColor3 = theme.Colors.Error
	close.TextColor3 = theme.Colors.TextOnPrimary
	close.ZIndex = 63
	UIStyler.Corner(1000).Parent = close
	UIStyler.Padding(6).Parent = close
	close.Activated:Connect(function()
		overlay.Visible = false
	end)
	close.Parent = card

	self._layoutPicker = overlay
end

-- ---- open/close animation picker --------------------------------------

function ThemeSelectorScreen:_OpenAnimPicker()
	self:_EnsureAnimPicker()
	self._animPicker.Visible = true
end

function ThemeSelectorScreen:_EnsureAnimPicker()
	if self._animPicker then
		return
	end
	local theme = self:GetTheme()
	local overlay = UIStyler.Frame("AnimPicker")
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.Visible = false
	overlay.ZIndex = 60
	overlay.Parent = self.Root

	local card = UIStyler.Frame("Card")
	card.Size = UDim2.fromScale(0.4, 0.56)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.BackgroundColor3 = theme.Colors.Surface
	card.ZIndex = 61
	UIStyler.Corner(12).Parent = card
	UIStyler.Padding(14).Parent = card
	card.Parent = overlay

	local title = UIStyler.TextLabel("Title")
	title.Size = UDim2.new(1, -36, 0, 28)
	title.Text = "🎞️ Open/Close Animation — applies to every menu"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.FontFace = theme.Fonts.Title
	title.TextSize = theme.TextSizes.Subtitle
	title.TextColor3 = theme.Colors.TextPrimary
	title.ZIndex = 62
	title.Parent = card

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, 0, 1, -40)
	list.Position = UDim2.fromOffset(0, 36)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.ZIndex = 62
	UIStyler.ListLayout({ Padding = UDim.new(0, 6) }).Parent = list
	list.Parent = card

	self._animButtons = {}
	for i, pack in PanelAnimConfig.Packs do
		local button = UIButtonComponent.new()
		button:Create(list, {
			text = pack.displayName,
			icon = pack.icon,
			variant = pack.id == PanelAnimConfig.ActiveId and "Primary" or "Ghost",
			size = UDim2.new(1, -6, 0, 44),
			layoutOrder = i,
			onClick = function()
				PanelAnimConfig.SetActive(pack.id)
				-- Re-open this very editor so the choice is instantly demonstrated
				-- with the new intro animation.
				overlay.Visible = false
				self.ScreenController:HideScreen("themeSelector")
				task.delay(0.28, function()
					self.ScreenController:ShowScreen("themeSelector")
				end)
			end,
		})
		table.insert(self._animButtons, button)
	end

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromOffset(28, 28)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Text = "✖"
	-- Same LegacyArial bug as the button icon fix: never assigning FontFace left
	-- this glyph on the emoji/symbol-incapable engine default.
	close.FontFace = theme.Fonts.Button
	close.TextScaled = true
	close.BackgroundColor3 = theme.Colors.Error
	close.TextColor3 = theme.Colors.TextOnPrimary
	close.ZIndex = 63
	UIStyler.Corner(1000).Parent = close
	UIStyler.Padding(6).Parent = close
	close.Activated:Connect(function()
		overlay.Visible = false
	end)
	close.Parent = card

	self._animPicker = overlay
end

function ThemeSelectorScreen:_Import()
	self:_EnsureOverlays()
	self._importOverlay.Visible = true
	self._importBox.Text = ""
	self._importHint.Text = self:_R("theme.import.hint")
	self._importBox:CaptureFocus()
end

function ThemeSelectorScreen:_TryApplyImport()
	local source = self._importBox.Text
	local theme, err = ThemeSerializer.Deserialize(source, self.ThemeController:GetTheme())
	if theme then
		self.ThemeController:UpsertRuntimeTheme(theme)
		self.ThemeController:ApplyThemeObject(theme)
		self:_LoadWorking(theme, false)
		self._importHint.Text = self:_R("theme.import.success")
		task.delay(0.8, function()
			if self._importOverlay then
				self._importOverlay.Visible = false
			end
		end)
	else
		self._importHint.Text = err or self:_R("theme.import.failed")
	end
end

-- Overlays are built lazily and themed from the current theme each open.
function ThemeSelectorScreen:_EnsureOverlays()
	if self._exportOverlay then
		return
	end
	self._exportOverlay, self._exportBox, self._exportHint = self:_BuildOverlay("theme.export", "📤", false)
	self._importOverlay, self._importBox, self._importHint = self:_BuildOverlay("theme.import", "📥", true)
end

function ThemeSelectorScreen:_BuildOverlay(titleKey: string, icon: string, isImport: boolean)
	local theme = self:GetTheme()
	local overlay = UIStyler.Frame("Overlay")
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.Visible = false
	overlay.ZIndex = 50
	overlay.Parent = self.Root

	local card = UIStyler.Frame("Card")
	card.Size = UDim2.fromScale(0.62, 0.72)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.BackgroundColor3 = theme.Colors.Surface
	card.ZIndex = 51
	UIStyler.Corner(12).Parent = card
	UIStyler.Padding(12).Parent = card
	card.Parent = overlay

	local title = UIStyler.TextLabel("Title")
	title.Size = UDim2.new(1, -36, 0, 26)
	title.Text = icon .. " " .. self:_R(titleKey)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.FontFace = theme.Fonts.Title
	title.TextSize = theme.TextSizes.Subtitle
	title.TextColor3 = theme.Colors.TextPrimary
	title.ZIndex = 52
	title.Parent = card

	-- The source viewer scrolls both ways: exported theme/pack modules are long
	-- and wide, and previously the raw TextBox ran off the card edges with no way
	-- to reach the rest. A ScrollingFrame wraps an auto-sizing TextBox so the full
	-- text is always reachable (drag to scroll) instead of clipped off-screen.
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "SourceScroll"
	scroll.Size = UDim2.new(1, 0, 1, -74)
	scroll.Position = UDim2.fromOffset(0, 30)
	scroll.BackgroundColor3 = theme.Colors.Background
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.XY
	scroll.ScrollBarThickness = 8
	scroll.ScrollingDirection = Enum.ScrollingDirection.XY
	scroll.ClipsDescendants = true
	scroll.ZIndex = 52
	UIStyler.Corner(8).Parent = scroll
	UIStyler.Padding(8).Parent = scroll
	scroll.Parent = card

	local box = Instance.new("TextBox")
	box.Name = "Source"
	-- Auto-size to content so the scroll frame's canvas grows to fit the module.
	box.Size = UDim2.fromScale(1, 0)
	box.AutomaticSize = Enum.AutomaticSize.XY
	box.BackgroundTransparency = 1
	box.TextColor3 = theme.Colors.TextPrimary
	box.PlaceholderText = isImport and "Paste an exported module here…" or ""
	box.FontFace = Font.fromEnum(Enum.Font.Code)
	box.TextSize = 12
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.ClearTextOnFocus = false
	box.MultiLine = true
	box.TextEditable = isImport
	box.TextWrapped = false
	box.ZIndex = 52
	box.Parent = scroll

	local hint = UIStyler.TextLabel("Hint")
	hint.Size = UDim2.new(1, -140, 0, 32)
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.fromScale(0, 1)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = theme.Colors.Success
	hint.FontFace = theme.Fonts.Body
	hint.TextSize = theme.TextSizes.Small
	hint.ZIndex = 52
	hint.Parent = card

	if isImport then
		local apply = UIButtonComponent.new()
		apply:Create(card, {
			textKey = "theme.import", variant = "Success",
			size = UDim2.new(0, 130, 0, 34),
			anchorPoint = Vector2.new(1, 1),
			position = UDim2.fromScale(1, 1),
			onClick = function() self:_TryApplyImport() end,
		})
		apply.Root.ZIndex = 53
	end

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromOffset(28, 28)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Text = "✖"
	-- Same LegacyArial bug as the button icon fix: never assigning FontFace left
	-- this glyph on the emoji/symbol-incapable engine default.
	close.FontFace = theme.Fonts.Button
	close.TextScaled = true
	close.BackgroundColor3 = theme.Colors.Error
	close.TextColor3 = theme.Colors.TextOnPrimary
	close.ZIndex = 53
	UIStyler.Corner(1000).Parent = close
	UIStyler.Padding(6).Parent = close
	close.Activated:Connect(function()
		overlay.Visible = false
	end)
	close.Parent = card

	return overlay, box, hint
end

function ThemeSelectorScreen:_OnShow()
	self:_LoadWorking(self.ThemeController:GetTheme(), false)
	-- Intro is driven centrally by UIScreenBase:Show (active animation pack).
end

return ThemeSelectorScreen

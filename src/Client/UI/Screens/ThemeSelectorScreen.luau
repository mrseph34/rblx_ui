--!strict
-- The runtime theme/pack auditioner AND full live theme editor.
--
-- Left column : swatch buttons for every registered theme + pack, applied on
--               click so the whole UI re-skins live.
-- Right column: an editor that edits a working copy of the current theme —
--               color fields for every token, plus sliders for radii, spacing,
--               animation time and effect scales. Every change calls
--               UIThemeController:ApplyThemeObject so the preview updates in
--               real time across all open screens.
--
-- Export : serializes the working theme to a drop-in .luau module via
--          ThemeSerializer and copies it to the clipboard (setclipboard where
--          available), also dropping it into a selectable TextBox so it can be
--          hand-copied and pasted — e.g. handed straight to a developer who
--          knows the theme-module template.
-- Import : parses a pasted module back into a theme and applies it, closing the
--          round-trip so pasted exports preview instantly.
--
-- Gated by DevConfig so it never ships to live players by accident.

local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local ThemeSerializer = require(script.Parent.Parent.Themes.ThemeSerializer)
local UIScreenBase = require(script.Parent.UIScreenBase)
local UIPanelComponent = require(script.Parent.Parent.Components.UIPanelComponent)
local UIButtonComponent = require(script.Parent.Parent.Components.UIButtonComponent)
local UISliderComponent = require(script.Parent.Parent.Components.UISliderComponent)
local UIColorFieldComponent = require(script.Parent.Parent.Components.UIColorFieldComponent)

local ThemeSelectorScreen = setmetatable({}, { __index = UIScreenBase })
ThemeSelectorScreen.__index = ThemeSelectorScreen

-- Which color tokens the editor exposes, in display order.
local COLOR_TOKENS = {
	"Primary", "Secondary", "Accent", "Background", "Surface", "SurfaceRaised",
	"Success", "Warning", "Error", "TextPrimary", "TextSecondary", "TextOnPrimary",
	"Stroke", "Overlay", "Disabled",
}

-- Numeric token sliders: {label, category, key, min, max, step}.
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
	return setmetatable(self, ThemeSelectorScreen)
end

-- Deep-ish clone so edits don't mutate the registered theme tables.
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
	panel:Create(self.Root, {
		titleKey = "theme.editor.title",
		size = UDim2.fromScale(0.8, 0.86),
		onClose = function()
			self.ScreenController:HideScreen("themeSelector")
		end,
	})

	-- Left column: theme + pack pickers.
	local left = UIStyler.Frame("Left")
	left.BackgroundTransparency = 1
	left.Size = UDim2.new(0.32, -8, 1, -16)
	left.Position = UDim2.fromOffset(8, 8)
	left.Parent = panel.Body
	self._left = left

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

	-- Right column: the editor + export/import.
	local right = UIStyler.Frame("Right")
	right.BackgroundTransparency = 1
	right.Size = UDim2.new(0.68, -16, 1, -16)
	right.Position = UDim2.new(0.32, 8, 0, 8)
	right.Parent = panel.Body
	self._right = right

	local editorScroll = Instance.new("ScrollingFrame")
	editorScroll.BackgroundTransparency = 1
	editorScroll.BorderSizePixel = 0
	editorScroll.Size = UDim2.new(1, 0, 1, -52)
	editorScroll.CanvasSize = UDim2.new()
	editorScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	editorScroll.ScrollBarThickness = 6
	UIStyler.ListLayout({ Padding = UDim.new(0, 6) }).Parent = editorScroll
	editorScroll.Parent = right
	self._editorScroll = editorScroll

	-- Export/Import action row at the bottom of the right column.
	local actionRow = UIStyler.Frame("Actions")
	actionRow.BackgroundTransparency = 1
	actionRow.Size = UDim2.new(1, 0, 0, 44)
	actionRow.AnchorPoint = Vector2.new(0, 1)
	actionRow.Position = UDim2.fromScale(0, 1)
	UIStyler.ListLayout({
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
	}).Parent = actionRow
	actionRow.Parent = right

	self._exportButton = UIButtonComponent.new()
	self._exportButton:Create(actionRow, {
		textKey = "theme.export",
		icon = "📤",
		variant = "Primary",
		size = UDim2.new(0, 150, 1, 0),
		layoutOrder = 1,
		onClick = function()
			self:_Export()
		end,
	})
	self._importButton = UIButtonComponent.new()
	self._importButton:Create(actionRow, {
		textKey = "theme.import",
		icon = "📥",
		variant = "Secondary",
		size = UDim2.new(0, 150, 1, 0),
		layoutOrder = 2,
		onClick = function()
			self:_Import()
		end,
	})
	self._resetButton = UIButtonComponent.new()
	self._resetButton:Create(actionRow, {
		textKey = "theme.reset",
		variant = "Ghost",
		size = UDim2.new(0, 110, 1, 0),
		layoutOrder = 3,
		onClick = function()
			self:_LoadWorking(self.ThemeController:GetTheme(), true)
		end,
	})

	self:_BuildThemeButtons()
	self:_BuildPackButtons()
end

function ThemeSelectorScreen:_BuildThemeButtons()
	local header = UIStyler.TextLabel("ThemesHeader")
	header.Size = UDim2.new(1, 0, 0, 24)
	header.Text = TextConfig.Resolve("theme.selector.title")
	header.LayoutOrder = 0
	header.Parent = self._leftScroll
	self._themesHeader = header

	for _, existing in self._themeButtons do
		existing:Destroy()
	end
	table.clear(self._themeButtons)

	for i, theme in self.ThemeController:GetThemeList() do
		local button = UIButtonComponent.new()
		button:Create(self._leftScroll, {
			text = theme.DisplayName,
			icon = "🎨",
			variant = "Ghost",
			size = UDim2.new(1, -8, 0, 44),
			layoutOrder = i,
			onClick = function()
				self.ThemeController:SetTheme(theme.Id)
				self:_LoadWorking(theme, true)
			end,
		})
		table.insert(self._themeButtons, button)
	end
end

function ThemeSelectorScreen:_BuildPackButtons()
	local header = UIStyler.TextLabel("PacksHeader")
	header.Size = UDim2.new(1, 0, 0, 24)
	header.Text = "Layout Packs"
	header.LayoutOrder = 100
	header.Parent = self._leftScroll
	self._packsHeader = header

	for i, pack in self.ThemeController:GetPackList() do
		local button = UIButtonComponent.new()
		button:Create(self._leftScroll, {
			text = pack.DisplayName,
			icon = "🧩",
			variant = "Ghost",
			size = UDim2.new(1, -8, 0, 40),
			layoutOrder = 100 + i,
			onClick = function()
				self.ThemeController:SetPack(pack.Id)
				-- Re-render open screens that depend on pack layout.
				if self.ScreenController:IsVisible("shop") then
					self.ScreenController:GetScreen("shop"):_RenderItems()
				end
			end,
		})
	end
end

-- Build a working copy of `theme` and (re)build all editor controls bound to it.
function ThemeSelectorScreen:_LoadWorking(theme: Types.UITheme, apply: boolean)
	self._working = cloneTheme(theme)
	self._working.Id = "Custom"
	self._working.DisplayName = "Custom"

	-- Tear down old controls.
	for _, field in self._colorFields do
		field:Destroy()
	end
	table.clear(self._colorFields)
	for _, slider in self._sliders do
		slider:Destroy()
	end
	table.clear(self._sliders)

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- Section label helper.
	local function sectionLabel(text: string)
		local label = UIStyler.TextLabel("Section")
		label.Size = UDim2.new(1, 0, 0, 26)
		label.Text = text
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.FontFace = self:GetTheme().Fonts.Subtitle
		label.TextSize = self:GetTheme().TextSizes.Subtitle
		label.TextColor3 = self:GetTheme().Colors.Accent
		label.LayoutOrder = nextOrder()
		label.Parent = self._editorScroll
	end

	sectionLabel("Colors")
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

	sectionLabel("Shape, Motion & Effects")
	for _, spec in NUMERIC_TOKENS do
		local label, category, key, min, max, step = spec[1], spec[2], spec[3], spec[4], spec[5], spec[6]
		local currentValue = self:_ReadNumeric(category, key)
		local slider = UISliderComponent.new()
		slider:Create(self._editorScroll, {
			label = label,
			min = min,
			max = max,
			step = step,
			value = currentValue,
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

-- Numeric token read/write handles the animation-time pseudo-categories that
-- map onto TweenInfo (which is immutable, so we rebuild it).
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

-- Push the working theme live to every component (real-time preview).
function ThemeSelectorScreen:_ApplyWorking()
	if self._working then
		self.ThemeController:ApplyThemeObject(self._working)
	end
end

-- ---- export -----------------------------------------------------------

function ThemeSelectorScreen:_Export()
	if not self._working then
		return
	end
	local source = ThemeSerializer.Serialize(self._working)
	self._exportBox.Text = source
	self._exportOverlay.Visible = true

	-- Copy to clipboard where the executor/plugin context allows it; otherwise
	-- fall back to the selectable box for manual copy.
	local copied = false
	local setclip = (rawget(getfenv(0), "setclipboard") or rawget(getfenv(0), "toclipboard")) :: any
	if typeof(setclip) == "function" then
		copied = pcall(setclip, source)
	end
	self._exportHint.Text = TextConfig.Resolve(copied and "theme.export.hint" or "theme.export.hint_manual")
	self._exportBox:CaptureFocus()
end

-- ---- import -----------------------------------------------------------

function ThemeSelectorScreen:_Import()
	self._importOverlay.Visible = true
	self._importBox.Text = ""
	self._importHint.Text = TextConfig.Resolve("theme.import.hint")
	self._importBox:CaptureFocus()
end

function ThemeSelectorScreen:_TryApplyImport()
	local source = self._importBox.Text
	local theme, err = ThemeSerializer.Deserialize(source, self.ThemeController:GetTheme())
	if theme then
		self.ThemeController:UpsertRuntimeTheme(theme)
		self.ThemeController:ApplyThemeObject(theme)
		self:_BuildThemeButtons()
		self:_LoadWorking(theme, false)
		self._importHint.Text = TextConfig.Resolve("theme.import.success")
		task.delay(0.8, function()
			self._importOverlay.Visible = false
		end)
	else
		self._importHint.Text = (err or TextConfig.Resolve("theme.import.failed"))
	end
end

-- Overlays for export/import are built once, lazily, over the panel.
function ThemeSelectorScreen:_BuildOverlays()
	-- Export overlay.
	local exportOverlay = UIStyler.Frame("ExportOverlay")
	exportOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
	exportOverlay.BackgroundTransparency = 0.35
	exportOverlay.Visible = false
	exportOverlay.ZIndex = 50
	exportOverlay.Parent = self.Root
	self._exportOverlay = exportOverlay

	local exportCard = UIStyler.Frame("Card")
	exportCard.Size = UDim2.fromScale(0.6, 0.7)
	exportCard.AnchorPoint = Vector2.new(0.5, 0.5)
	exportCard.Position = UDim2.fromScale(0.5, 0.5)
	exportCard.BackgroundColor3 = self:GetTheme().Colors.Surface
	exportCard.ZIndex = 51
	UIStyler.Corner(12).Parent = exportCard
	UIStyler.Padding(12).Parent = exportCard
	exportCard.Parent = exportOverlay

	local exportTitle = UIStyler.TextLabel("Title")
	exportTitle.Size = UDim2.new(1, 0, 0, 26)
	exportTitle.Text = "📤 " .. TextConfig.Resolve("theme.export")
	exportTitle.TextXAlignment = Enum.TextXAlignment.Left
	exportTitle.FontFace = self:GetTheme().Fonts.Title
	exportTitle.TextSize = self:GetTheme().TextSizes.Subtitle
	exportTitle.TextColor3 = self:GetTheme().Colors.TextPrimary
	exportTitle.ZIndex = 52
	exportTitle.Parent = exportCard

	local exportBox = Instance.new("TextBox")
	exportBox.Name = "Source"
	exportBox.Size = UDim2.new(1, 0, 1, -70)
	exportBox.Position = UDim2.fromOffset(0, 30)
	exportBox.BackgroundColor3 = self:GetTheme().Colors.Background
	exportBox.TextColor3 = self:GetTheme().Colors.TextPrimary
	exportBox.FontFace = Font.fromEnum(Enum.Font.Code)
	exportBox.TextSize = 12
	exportBox.TextXAlignment = Enum.TextXAlignment.Left
	exportBox.TextYAlignment = Enum.TextYAlignment.Top
	exportBox.TextWrapped = false
	exportBox.ClearTextOnFocus = false
	exportBox.MultiLine = true
	exportBox.TextEditable = false
	exportBox.ZIndex = 52
	UIStyler.Corner(8).Parent = exportBox
	UIStyler.Padding(8).Parent = exportBox
	exportBox.Parent = exportCard
	self._exportBox = exportBox

	self._exportHint = UIStyler.TextLabel("Hint")
	self._exportHint.Size = UDim2.new(1, -110, 0, 30)
	self._exportHint.AnchorPoint = Vector2.new(0, 1)
	self._exportHint.Position = UDim2.fromScale(0, 1)
	self._exportHint.TextXAlignment = Enum.TextXAlignment.Left
	self._exportHint.TextColor3 = self:GetTheme().Colors.Success
	self._exportHint.ZIndex = 52
	self._exportHint.Parent = exportCard

	local exportClose = self:_MakeOverlayClose(exportCard, function()
		exportOverlay.Visible = false
	end)
	exportClose.Parent = exportCard

	-- Import overlay.
	local importOverlay = UIStyler.Frame("ImportOverlay")
	importOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
	importOverlay.BackgroundTransparency = 0.35
	importOverlay.Visible = false
	importOverlay.ZIndex = 50
	importOverlay.Parent = self.Root
	self._importOverlay = importOverlay

	local importCard = UIStyler.Frame("Card")
	importCard.Size = UDim2.fromScale(0.6, 0.7)
	importCard.AnchorPoint = Vector2.new(0.5, 0.5)
	importCard.Position = UDim2.fromScale(0.5, 0.5)
	importCard.BackgroundColor3 = self:GetTheme().Colors.Surface
	importCard.ZIndex = 51
	UIStyler.Corner(12).Parent = importCard
	UIStyler.Padding(12).Parent = importCard
	importCard.Parent = importOverlay

	local importTitle = UIStyler.TextLabel("Title")
	importTitle.Size = UDim2.new(1, 0, 0, 26)
	importTitle.Text = "📥 " .. TextConfig.Resolve("theme.import")
	importTitle.TextXAlignment = Enum.TextXAlignment.Left
	importTitle.FontFace = self:GetTheme().Fonts.Title
	importTitle.TextSize = self:GetTheme().TextSizes.Subtitle
	importTitle.TextColor3 = self:GetTheme().Colors.TextPrimary
	importTitle.ZIndex = 52
	importTitle.Parent = importCard

	local importBox = Instance.new("TextBox")
	importBox.Name = "Source"
	importBox.Size = UDim2.new(1, 0, 1, -70)
	importBox.Position = UDim2.fromOffset(0, 30)
	importBox.BackgroundColor3 = self:GetTheme().Colors.Background
	importBox.TextColor3 = self:GetTheme().Colors.TextPrimary
	importBox.PlaceholderText = "Paste an exported theme module here…"
	importBox.FontFace = Font.fromEnum(Enum.Font.Code)
	importBox.TextSize = 12
	importBox.TextXAlignment = Enum.TextXAlignment.Left
	importBox.TextYAlignment = Enum.TextYAlignment.Top
	importBox.ClearTextOnFocus = false
	importBox.MultiLine = true
	importBox.ZIndex = 52
	UIStyler.Corner(8).Parent = importBox
	UIStyler.Padding(8).Parent = importBox
	importBox.Parent = importCard
	self._importBox = importBox

	self._importHint = UIStyler.TextLabel("Hint")
	self._importHint.Size = UDim2.new(1, -130, 0, 30)
	self._importHint.AnchorPoint = Vector2.new(0, 1)
	self._importHint.Position = UDim2.fromScale(0, 1)
	self._importHint.TextXAlignment = Enum.TextXAlignment.Left
	self._importHint.TextColor3 = self:GetTheme().Colors.TextSecondary
	self._importHint.ZIndex = 52
	self._importHint.Parent = importCard

	local applyImport = UIButtonComponent.new()
	applyImport:Create(importCard, {
		textKey = "theme.import",
		variant = "Success",
		size = UDim2.new(0, 120, 0, 34),
		anchorPoint = Vector2.new(1, 1),
		position = UDim2.fromScale(1, 1),
		onClick = function()
			self:_TryApplyImport()
		end,
	})
	applyImport.Root.ZIndex = 53

	local importClose = self:_MakeOverlayClose(importCard, function()
		importOverlay.Visible = false
	end)
	importClose.Parent = importCard
end

function ThemeSelectorScreen:_MakeOverlayClose(_parent: Instance, onClose: () -> ()): TextButton
	local close = Instance.new("TextButton")
	close.Name = "OverlayClose"
	close.Size = UDim2.fromOffset(28, 28)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Text = "✕"
	close.TextScaled = true
	close.BackgroundColor3 = self:GetTheme().Colors.Error
	close.TextColor3 = self:GetTheme().Colors.TextOnPrimary
	close.ZIndex = 53
	UIStyler.Corner(1000).Parent = close
	UIStyler.Padding(6).Parent = close
	close.Activated:Connect(onClose)
	return close
end

function ThemeSelectorScreen:_OnShow()
	if not self._exportOverlay then
		self:_BuildOverlays()
	end
	self:_BuildThemeButtons()
	self:_LoadWorking(self.ThemeController:GetTheme(), false)
	self._panel:PlayAnimation("Appear")
end

return ThemeSelectorScreen

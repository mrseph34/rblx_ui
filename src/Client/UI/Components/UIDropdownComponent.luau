--!strict
-- Labelled option picker (dropdown) for settings-style rows. Shows the current
-- option; clicking opens a themed list of choices below it. Emits onChanged with
-- the picked option id. Kept structurally like the toggle/slider so a settings
-- list of mixed controls stays visually consistent.
--
-- Extra props:
--   labelKey / label
--   options   : { { id: string, text: string } }
--   value     : id of the initial selection
--   onChanged : (id: string) -> ()

local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local ThemeShape = require(script.Parent.Parent.ThemeShape)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local UIComponentBase = require(script.Parent.UIComponentBase)

local UIDropdownComponent = setmetatable({}, { __index = UIComponentBase })
UIDropdownComponent.__index = UIDropdownComponent

function UIDropdownComponent.new()
	local self = UIComponentBase.new("UIDropdown")
	self._options = {}
	self._optionButtons = {}
	self._open = false
	return setmetatable(self, UIDropdownComponent)
end

function UIDropdownComponent:_Build(props: Types.UIComponentProps)
	self._options = (props :: any).options or {}
	self._value = (props :: any).value or (self._options[1] and self._options[1].id)
	local root = self.Root
	root.BackgroundTransparency = 1
	if not props.size then
		root.Size = UDim2.new(1, 0, 0, 36)
		self._baseSize = root.Size
	end
	-- Overflow the open list beyond the row's own height.
	root.ClipsDescendants = false

	local label = UIStyler.TextLabel("Label")
	label.Size = UDim2.new(1, -170, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = TextConfig.Resolve(props.labelKey or props.label)
	label.Parent = root
	self._label = label

	-- Current-value button (right-aligned).
	local current = Instance.new("TextButton")
	current.Name = "Current"
	current.AutoButtonColor = false
	current.Size = UDim2.fromOffset(160, 30)
	current.AnchorPoint = Vector2.new(1, 0.5)
	current.Position = UDim2.new(1, 0, 0.5, 0)
	current.Text = ""
	current.ZIndex = 2
	self._currentCorner = UIStyler.Corner(8)
	self._currentCorner.Parent = current
	self._currentStroke = UIStyler.Stroke(Color3.new(), 1)
	self._currentStroke.Parent = current
	UIStyler.PaddingXY(10, 0).Parent = current
	current.Parent = root
	self._current = current

	local currentText = UIStyler.TextLabel("Value")
	currentText.Size = UDim2.new(1, -20, 1, 0)
	currentText.TextXAlignment = Enum.TextXAlignment.Left
	currentText.ZIndex = 2
	currentText.Parent = current
	self._currentText = currentText

	local arrow = UIStyler.TextLabel("Arrow")
	arrow.Size = UDim2.fromOffset(16, 16)
	arrow.AnchorPoint = Vector2.new(1, 0.5)
	arrow.Position = UDim2.new(1, 0, 0.5, 0)
	arrow.Text = "▾"
	arrow.TextScaled = true
	arrow.ZIndex = 2
	arrow.Parent = current
	self._arrow = arrow

	-- Option list (hidden until opened), drops below the current button.
	local list = UIStyler.Frame("Options")
	list.Visible = false
	list.AnchorPoint = Vector2.new(1, 0)
	list.Position = UDim2.new(1, 0, 0.5, 18)
	list.Size = UDim2.fromOffset(160, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.ZIndex = 20
	self._listCorner = UIStyler.Corner(8)
	self._listCorner.Parent = list
	self._listStroke = UIStyler.Stroke(Color3.new(), 1)
	self._listStroke.Parent = list
	UIStyler.Padding(4).Parent = list
	UIStyler.ListLayout({ Padding = UDim.new(0, 2) }).Parent = list
	list.Parent = root
	self._list = list

	self:_Connect(current.Activated, function()
		self:_Toggle()
	end)
	self:_RebuildOptions()
	self:_SyncCurrentText()
end

function UIDropdownComponent:_RebuildOptions()
	for _, b in self._optionButtons do
		b:Destroy()
	end
	table.clear(self._optionButtons)
	for i, opt in self._options do
		local btn = Instance.new("TextButton")
		btn.Name = "opt_" .. opt.id
		btn.AutoButtonColor = false
		btn.Size = UDim2.new(1, 0, 0, 28)
		btn.LayoutOrder = i
		btn.Text = opt.text
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.BackgroundTransparency = 1
		btn.ZIndex = 21
		UIStyler.PaddingXY(8, 0).Parent = btn
		btn.Parent = self._list
		self:_Connect(btn.Activated, function()
			self:Set(opt.id, true)
			self:_Toggle()
		end)
		table.insert(self._optionButtons, btn)
	end
end

function UIDropdownComponent:_Toggle()
	self._open = not self._open
	self._list.Visible = self._open
	self._arrow.Text = self._open and "▴" or "▾"
end

function UIDropdownComponent:Set(id: string, notify: boolean?)
	self._value = id
	self:_SyncCurrentText()
	if self.Theme then
		self:_Style(self.Theme)
	end
	if notify and self.Props.onChanged then
		self.Props.onChanged(id)
	end
end

function UIDropdownComponent:GetValue(): string
	return self._value
end

function UIDropdownComponent:_SyncCurrentText()
	for _, opt in self._options do
		if opt.id == self._value then
			self._currentText.Text = opt.text
			return
		end
	end
	self._currentText.Text = ""
end

function UIDropdownComponent:_Style(theme: Types.UITheme)
	local c = theme.Colors
	local radius = ThemeShape.Radius(theme, theme.Radii.Small)
	self._label.FontFace = theme.Fonts.Body
	self._label.TextSize = theme.TextSizes.Body
	self._label.TextColor3 = c.TextPrimary

	self._current.BackgroundColor3 = c.SurfaceRaised
	self._currentCorner.CornerRadius = UDim.new(0, radius)
	self._currentStroke.Color = c.Stroke
	self._currentStroke.Thickness = theme.Effects.StrokeThickness
	self._currentText.FontFace = theme.Fonts.Body
	self._currentText.TextSize = theme.TextSizes.Body
	self._currentText.TextColor3 = c.TextPrimary
	-- Same LegacyArial bug as the button icon fix: never assigning FontFace left
	-- this glyph (▾/▴) on the emoji/symbol-incapable engine default.
	self._arrow.FontFace = theme.Fonts.Body
	self._arrow.TextColor3 = c.TextSecondary

	self._list.BackgroundColor3 = c.Surface
	self._listCorner.CornerRadius = UDim.new(0, radius)
	self._listStroke.Color = c.Stroke
	self._listStroke.Thickness = theme.Effects.StrokeThickness
	for _, btn in self._optionButtons do
		btn.FontFace = theme.Fonts.Body
		btn.TextSize = theme.TextSizes.Body
		-- Highlight the selected option.
		local selected = string.sub(btn.Name, 5) == self._value
		btn.TextColor3 = selected and c.Accent or c.TextSecondary
	end
end

function UIDropdownComponent:Destroy()
	for _, b in self._optionButtons do
		b:Destroy()
	end
	UIComponentBase.Destroy(self)
end

return UIDropdownComponent

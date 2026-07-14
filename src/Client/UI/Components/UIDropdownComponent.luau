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
	label.Size = UDim2.fromScale(0.55, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextScaled = true
	self._labelConstraint = UIStyler.TextSizeConstraint(16, 8)
	self._labelConstraint.Parent = label
	label.Text = TextConfig.Resolve(props.labelKey or props.label)
	label.Parent = root
	self._label = label

	-- Current-value button (right-aligned) — pure Scale fractions of Root,
	-- never a fixed pixel Offset.
	local current = Instance.new("TextButton")
	current.Name = "Current"
	current.AutoButtonColor = false
	current.Size = UDim2.fromScale(0.42, 0.78)
	current.AnchorPoint = Vector2.new(1, 0.5)
	current.Position = UDim2.new(1, 0, 0.5, 0)
	current.Text = ""
	current.ZIndex = 2
	self._currentCorner = UIStyler.Corner(8)
	self._currentCorner.Parent = current
	self._currentStroke = UIStyler.Stroke(Color3.new(), 1)
	self._currentStroke.Parent = current
	-- Boxy gradient fill so the value box matches the rest of the base UI.
	self._currentGradient = UIStyler.Gradient(90, 0.16)
	self._currentGradient.Parent = current
	UIStyler.PaddingXY(10, 0).Parent = current
	current.Parent = root
	self._current = current

	local currentText = UIStyler.TextLabel("Value")
	currentText.Size = UDim2.fromScale(0.75, 1)
	currentText.TextXAlignment = Enum.TextXAlignment.Left
	currentText.TextScaled = true
	self._currentTextConstraint = UIStyler.TextSizeConstraint(16, 8)
	self._currentTextConstraint.Parent = currentText
	currentText.ZIndex = 2
	currentText.Parent = current
	self._currentText = currentText

	-- Arrow glyph box is a perfect square (AspectRatioConstraint 1:1,
	-- DominantAxis Height) instead of a fixed pixel Offset, so it scales
	-- with `current`'s real resolved height. Starting size is non-zero on
	-- both axes (never Scale=0) — an AspectRatioConstraint driving a
	-- Scale=0 starting dimension collapses to 0x0 instead of resolving.
	local arrow = UIStyler.TextLabel("Arrow")
	arrow.Size = UDim2.fromScale(0.5, 0.5)
	arrow.AnchorPoint = Vector2.new(1, 0.5)
	arrow.Position = UDim2.new(1, 0, 0.5, 0)
	UIStyler.AspectRatio(1, Enum.DominantAxis.Height).Parent = arrow
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
	list.Size = UDim2.fromScale(0.42, 0)
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
		btn.TextScaled = true
		local optConstraint = UIStyler.TextSizeConstraint(16, 8)
		optConstraint.Parent = btn
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
	self._label.TextColor3 = c.TextPrimary
	if self._labelConstraint then
		self._labelConstraint.MaxTextSize = theme.TextSizes.Body
	end

	self._current.BackgroundColor3 = c.SurfaceRaised
	self._currentCorner.CornerRadius = UDim.new(0, radius)
	self._currentStroke.Color = c.Stroke
	self._currentStroke.Thickness = theme.Effects.StrokeThickness
	self._currentGradient.Enabled = theme.Effects.UseGradients
	self._currentText.FontFace = theme.Fonts.Body
	self._currentText.TextColor3 = c.TextPrimary
	if self._currentTextConstraint then
		self._currentTextConstraint.MaxTextSize = theme.TextSizes.Body
	end
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
		local optConstraint = btn:FindFirstChildOfClass("UITextSizeConstraint")
		if optConstraint then
			optConstraint.MaxTextSize = theme.TextSizes.Body
		end
		-- Base boxy UI: option text is white; the SELECTED option is marked by a
		-- subtle raised background box instead of a gold text colour (the theme's
		-- navy outline keeps the white text legible on it).
		local selected = string.sub(btn.Name, 5) == self._value
		btn.TextColor3 = c.TextPrimary
		btn.BackgroundColor3 = c.SurfaceRaised
		btn.BackgroundTransparency = selected and 0.15 or 1
	end
end

function UIDropdownComponent:Destroy()
	for _, b in self._optionButtons do
		b:Destroy()
	end
	UIComponentBase.Destroy(self)
end

return UIDropdownComponent

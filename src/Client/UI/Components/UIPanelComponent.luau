--!strict
-- Generic centered container for modals, tutorial popups and editor windows.
-- Provides a titled header bar with an optional close button and a Body frame
-- children are parented into. Animates in/out via the base Appear/Disappear.
--
-- Extra props:
--   titleKey / title
--   showClose : boolean
--   onClose   : () -> ()

local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local UIComponentBase = require(script.Parent.UIComponentBase)

local UIPanelComponent = setmetatable({}, { __index = UIComponentBase })
UIPanelComponent.__index = UIPanelComponent

function UIPanelComponent.new()
	local self = UIComponentBase.new("UIPanel")
	return setmetatable(self, UIPanelComponent)
end

function UIPanelComponent:_Build(props: Types.UIComponentProps)
	local root = self.Root
	root.BackgroundTransparency = 0
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	if not props.position then
		root.Position = UDim2.fromScale(0.5, 0.5)
	end
	if not props.size then
		root.Size = UDim2.fromScale(0.42, 0.5)
		self._baseSize = root.Size
	end

	self._corner = UIStyler.Corner(16)
	self._corner.Parent = root
	self._stroke = UIStyler.Stroke(Color3.new(), 1.5)
	self._stroke.Parent = root

	-- Drop shadow (a soft image behind the panel).
	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxassetid://5028857084"
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(24, 24, 276, 276)
	shadow.Size = UDim2.new(1, 40, 1, 40)
	shadow.Position = UDim2.new(0, -20, 0, -16)
	shadow.ZIndex = 0
	shadow.Parent = root
	self._shadow = shadow

	-- Header.
	local header = UIStyler.Frame("Header")
	header.Size = UDim2.new(1, 0, 0, 44)
	header.BackgroundTransparency = 0
	header.ZIndex = 2
	UIStyler.Corner(16).Parent = header
	UIStyler.PaddingXY(14, 0).Parent = header
	header.Parent = root
	self._header = header

	local title = UIStyler.TextLabel("Title")
	title.Size = UDim2.new(1, -40, 1, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = TextConfig.Resolve(props.titleKey or props.title)
	title.ZIndex = 2
	title.Parent = header
	self._title = title

	if props.showClose ~= false then
		local close = Instance.new("TextButton")
		close.Name = "Close"
		close.Size = UDim2.fromOffset(30, 30)
		close.AnchorPoint = Vector2.new(1, 0.5)
		close.Position = UDim2.new(1, -6, 0.5, 0)
		close.Text = "✖"
		close.TextScaled = true
		close.BackgroundTransparency = 0
		close.AutoButtonColor = true
		close.ZIndex = 3
		UIStyler.Corner(1000).Parent = close
		UIStyler.Padding(6).Parent = close
		close.Parent = header
		self._close = close
		self:_Connect(close.Activated, function()
			if props.onClose then
				props.onClose()
			end
		end)
	end

	-- Body: children go here.
	local body = UIStyler.Frame("Body")
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 1, -44)
	body.Position = UDim2.new(0, 0, 0, 44)
	body.ZIndex = 2
	body.Parent = root
	self.Body = body
end

function UIPanelComponent:_Style(theme: Types.UITheme)
	local c = theme.Colors
	self:_SetColor(self.Root, "BackgroundColor3", c.Surface)
	self:_SetColor(self._header, "BackgroundColor3", c.SurfaceRaised)
	self._corner.CornerRadius = UDim.new(0, theme.Radii.Large)
	self._stroke.Color = c.Stroke
	self._stroke.Thickness = theme.Effects.StrokeThickness
	self._stroke.Transparency = 0.3
	self._shadow.ImageTransparency = theme.Effects.ShadowTransparency
	self._shadow.ImageColor3 = c.Overlay

	self._title.FontFace = theme.Fonts.Title
	self._title.TextSize = theme.TextSizes.Title
	self._title.TextColor3 = c.TextPrimary
	if self._close then
		self._close.BackgroundColor3 = c.Error
		self._close.TextColor3 = c.TextOnPrimary
		self._close.FontFace = theme.Fonts.Button
	end
end

return UIPanelComponent

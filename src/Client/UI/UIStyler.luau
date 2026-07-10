--!strict
-- Low-level GuiObject builders shared by every component and screen. This is
-- where raw Instance.new calls live so components stay declarative. Nothing
-- here reads the theme directly — callers pass resolved values in. Keeping the
-- primitives theme-agnostic is what lets a live theme swap just re-apply
-- values to instances these functions already created.

local TweenService = game:GetService("TweenService")

local UIStyler = {}

-- Tween a set of properties on an instance, returning the Tween so callers can
-- wait on Completed or cancel it. Centralised so every animation goes through
-- one path (easier to profile / globally disable for reduced-motion later).
function UIStyler.Tween(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

function UIStyler.Corner(radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	return corner
end

function UIStyler.Stroke(color: Color3, thickness: number, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return stroke
end

function UIStyler.Padding(all: number): UIPadding
	local padding = Instance.new("UIPadding")
	local offset = UDim.new(0, all)
	padding.PaddingTop = offset
	padding.PaddingBottom = offset
	padding.PaddingLeft = offset
	padding.PaddingRight = offset
	return padding
end

function UIStyler.PaddingXY(x: number, y: number): UIPadding
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, x)
	padding.PaddingRight = UDim.new(0, x)
	padding.PaddingTop = UDim.new(0, y)
	padding.PaddingBottom = UDim.new(0, y)
	return padding
end

-- Vertical two-stop gradient used for the "raised"/glossy look. Intensity 0
-- yields a flat fill; higher values brighten the top and darken the bottom.
function UIStyler.Gradient(rotation: number, intensity: number): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	-- The gradient multiplies the frame's BackgroundColor3. Color3 channels max
	-- out at 1, so we can't brighten past the base color — instead keep the top
	-- at full and darken toward the bottom for a subtle "lit from above" depth.
	local bottom = math.clamp(1 - intensity, 0, 1)
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(bottom, bottom, bottom)),
	})
	return gradient
end

function UIStyler.ListLayout(props: { [string]: any }?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	if props then
		for key, value in props do
			(layout :: any)[key] = value
		end
	end
	return layout
end

function UIStyler.GridLayout(cellSize: UDim2, padding: UDim2): UIGridLayout
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = cellSize
	layout.CellPadding = padding
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	return layout
end

-- Blank frame with no default chrome — the base every component builds on.
function UIStyler.Frame(name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	return frame
end

function UIStyler.TextLabel(name: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Text = ""
	label.TextScaled = false
	label.RichText = true
	label.TextColor3 = Color3.new(1, 1, 1)
	return label
end

-- Constrains TextScaled labels so scaled text never becomes comically large.
function UIStyler.TextSizeConstraint(max: number, min: number?): UITextSizeConstraint
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = max
	constraint.MinTextSize = min or 6
	return constraint
end

return UIStyler

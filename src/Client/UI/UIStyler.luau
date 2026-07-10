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

-- Locks an element to a fixed width:height ratio. Used by image slots so the
-- focal image is square (or any ratio) on every screen size and never stretches.
-- dominant "Width" means height follows width; the layout still bounds it.
function UIStyler.AspectRatio(ratio: number, dominant: Enum.DominantAxis?): UIAspectRatioConstraint
	local constraint = Instance.new("UIAspectRatioConstraint")
	constraint.AspectRatio = ratio
	constraint.DominantAxis = dominant or Enum.DominantAxis.Width
	constraint.AspectType = Enum.AspectType.FitWithinMaxSize
	return constraint
end

-- A soft drop shadow behind a surface, made from a stretched radial image so it
-- reads on any theme. Parent it as a sibling *behind* the surface (lower ZIndex).
-- offsetY pushes it down for the "raised" look; transparency 1 hides it.
--
-- growPx controls how far the shadow bleeds past the surface's own edges
-- (default 24, fine for isolated elements like buttons/panels with room to
-- spare). Anything that tiles edge-to-edge in a tight grid — shop cards with
-- only ~10px between them — MUST pass a smaller growPx, or the shadow bleeds
-- into the neighbouring cell and gets abruptly sliced off by that card's own
-- opaque surface sitting on top of it (a visible, unprofessional hard cutoff).
function UIStyler.DropShadow(offsetY: number, transparency: number, growPx: number?): ImageLabel
	local grow = growPx or 24
	local shadow = Instance.new("ImageLabel")
	shadow.Name = "DropShadow"
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxassetid://5554236805" -- soft 9-slice glow
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(23, 23, 277, 277)
	shadow.ImageColor3 = Color3.new(0, 0, 0)
	shadow.ImageTransparency = transparency
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.new(0.5, 0, 0.5, offsetY)
	shadow.Size = UDim2.new(1, grow, 1, grow + offsetY)
	shadow.ZIndex = 0
	return shadow
end

-- Inner bevel for the Raised3D style: a UIGradient-driven vertical light->dark
-- overlay clipped to the surface, giving a top highlight and bottom shade so the
-- surface reads as an extruded, physical button. transparency 0..1 tunes strength.
function UIStyler.Bevel(highlightTransparency: number, shadowStrength: number): Frame
	local bevel = Instance.new("Frame")
	bevel.Name = "Bevel"
	bevel.BackgroundColor3 = Color3.new(1, 1, 1)
	bevel.BackgroundTransparency = 0
	bevel.BorderSizePixel = 0
	bevel.Size = UDim2.fromScale(1, 1)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
	})
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, highlightTransparency),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, math.clamp(1 - shadowStrength, 0, 1)),
	})
	gradient.Parent = bevel
	return bevel
end

-- Constrains TextScaled labels so scaled text never becomes comically large.
function UIStyler.TextSizeConstraint(max: number, min: number?): UITextSizeConstraint
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = max
	constraint.MinTextSize = min or 6
	return constraint
end

return UIStyler

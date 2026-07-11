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
local ThemeShape = require(script.Parent.Parent.ThemeShape)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local PanelAnimConfig = require(script.Parent.Parent.Config.PanelAnimConfig)
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
	-- Resting position the intro/outro animations tween to/from.
	self._restPosition = root.Position
	if not props.size then
		root.Size = UDim2.fromScale(0.42, 0.5)
		self._baseSize = root.Size
	end

	self._corner = UIStyler.Corner(16)
	self._corner.Parent = root
	self._stroke = UIStyler.Stroke(Color3.new(), 1.5)
	self._stroke.Parent = root

	-- Header. A plain rectangular BG frame behind it draws ONLY the top two
	-- corners rounded (via a UICorner ONLY it has) so the header's own BOTTOM
	-- edge — an interior seam against Body, not the panel's outer edge — never
	-- shows a rounded "border" there. Header itself stays square so its
	-- children (title/close) lay out against simple edges.
	local header = UIStyler.Frame("Header")
	header.Size = UDim2.new(1, 0, 0, 44)
	header.BackgroundTransparency = 1
	header.ZIndex = 2
	header.Parent = root
	self._header = header
	-- Public (like Body): a screen can parent extra header-row content here
	-- (e.g. ShopScreen's currency chips, so money sits next to the close
	-- button instead of eating its own separate row in Body).
	self.Header = header

	local headerBg = UIStyler.Frame("HeaderBg")
	headerBg.Size = UDim2.fromScale(1, 1)
	headerBg.BackgroundTransparency = 0
	headerBg.ZIndex = 1
	headerBg.Parent = header
	self._headerBg = headerBg
	-- Rounded on all 4 corners, but only the TOP two are ever visible: the
	-- bottom half of headerBg is clipped by a taller plain rect stacked under
	-- it that covers the bottom-left/right rounding without covering the top.
	self._headerCorner = UIStyler.Corner(16)
	self._headerCorner.Parent = headerBg
	local headerSquareBottom = UIStyler.Frame("SquareBottom")
	headerSquareBottom.AnchorPoint = Vector2.new(0, 1)
	headerSquareBottom.Position = UDim2.fromScale(0, 1)
	headerSquareBottom.Size = UDim2.new(1, 0, 0.5, 0)
	headerSquareBottom.BackgroundTransparency = 0
	headerSquareBottom.ZIndex = 1
	headerSquareBottom.Parent = headerBg
	self._headerSquareBottom = headerSquareBottom

	-- Header padding is a SCALE fraction of the header's own height (not a
	-- fixed pixel inset), so title/close positioning scales with the rest of
	-- the UI instead of the X drifting inward by a constant amount at any size.
	UIStyler.PaddingScale(0.14).Parent = header

	local title = UIStyler.TextLabel("Title")
	-- Leaves room for the close button (a Scale fraction of header width, not a
	-- stale pixel reservation) when one is shown; full width otherwise.
	title.Size = UDim2.new(props.showClose ~= false and 0.82 or 1, 0, 1, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = TextConfig.Resolve(props.titleKey or props.title)
	title.TextScaled = true
	title.TextWrapped = false
	title.ZIndex = 2
	self._titleConstraint = UIStyler.TextSizeConstraint(28, 10)
	self._titleConstraint.Parent = title
	title.Parent = header
	self._title = title

	if props.showClose ~= false then
		local close = Instance.new("TextButton")
		close.Name = "Close"
		close.AnchorPoint = Vector2.new(1, 0.5)
		-- Pinned to the FAR right edge of the header (Scale, not a header-padding-
		-- eaten pixel inset) — a small POSITIVE X offset re-escapes header's own
		-- UIPadding so the X sits flush near the true panel edge, not inset by
		-- the same padding the title/content use.
		close.Position = UDim2.new(1, 12, 0.5, 0)
		-- Placeholder; _Style computes the real SQUARE size from header's actual
		-- AbsoluteSize.Y once resolvable — an AspectRatioConstraint here would
		-- collapse to 0x0 (Size.X starts at Scale=0 with no offset, and
		-- FitWithinMaxSize fits the ratio inside THAT zero-width box), the same
		-- documented landmine UIButtonComponent's icon sizing already hit.
		close.Size = UDim2.fromOffset(30, 30)
		close.Text = "✖"
		close.TextScaled = true
		close.BackgroundTransparency = 0
		close.AutoButtonColor = true
		close.ZIndex = 3
		UIStyler.Corner(1000).Parent = close
		UIStyler.PaddingScale(0.2).Parent = close
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

-- Animate the panel IN using the active PanelAnimConfig pack: start from the
-- pack's transform (scaled down, or slid off to a side) and tween to rest. On
-- close, AnimateOut plays the same transform in reverse. Returns the driving
-- Tween so callers (screens) can wait on Completed.
function UIPanelComponent:AnimateIn(): Tween?
	local theme = self.Theme
	if not theme then
		self.Root.Visible = true
		return nil
	end
	local pack = PanelAnimConfig.Active()
	self.Root.Visible = true
	if pack.mode == "Slide" then
		local offset = pack.offset or UDim2.new()
		self.Root.Position = self._restPosition + offset
		-- Ensure the scale is neutral (a previous Scale pack may have left it <1).
		local scale = self:_EnsureScale()
		scale.Scale = 1
		return self:_Tween(self.Root, theme.Animations.Appear, { Position = self._restPosition })
	else
		-- Scale (grow/pop). Reset any slide offset first.
		self.Root.Position = self._restPosition
		local scale = self:_EnsureScale()
		scale.Scale = pack.scale or 0.85
		return self:_Tween(scale, theme.Animations.Appear, { Scale = 1 })
	end
end

-- Reverse of AnimateIn: tween back to the pack's start transform, so the panel
-- leaves the way it came instead of vanishing. Returns the Tween so the screen
-- can disable its Gui only once the exit finishes.
function UIPanelComponent:AnimateOut(): Tween?
	local theme = self.Theme
	if not theme then
		return nil
	end
	local pack = PanelAnimConfig.Active()
	if pack.mode == "Slide" then
		local offset = pack.offset or UDim2.new()
		return self:_Tween(self.Root, theme.Animations.Disappear, { Position = self._restPosition + offset })
	else
		local scale = self:_EnsureScale()
		return self:_Tween(scale, theme.Animations.Disappear, { Scale = pack.scale or 0.85 })
	end
end

function UIPanelComponent:_Style(theme: Types.UITheme)
	local c = theme.Colors
	self:_SetColor(self.Root, "BackgroundColor3", c.Surface)
	self:_SetColor(self._headerBg, "BackgroundColor3", c.SurfaceRaised)
	self:_SetColor(self._headerSquareBottom, "BackgroundColor3", c.SurfaceRaised)
	local radius = ThemeShape.Radius(theme, theme.Radii.Large)
	self._corner.CornerRadius = UDim.new(0, radius)
	self._headerCorner.CornerRadius = UDim.new(0, radius)
	self._stroke.Color = c.Stroke
	self._stroke.Thickness = theme.Effects.StrokeThickness
	self._stroke.Transparency = 0.3

	self._title.FontFace = theme.Fonts.Title
	self._title.TextColor3 = c.TextPrimary
	if self._titleConstraint then
		self._titleConstraint.MaxTextSize = theme.TextSizes.Title
	end
	if self._close then
		self._close.BackgroundColor3 = c.Error
		self._close.TextColor3 = c.TextOnPrimary
		self._close.FontFace = theme.Fonts.Button
		-- Square, scaled from the header's real resolved height (not an
		-- AspectRatioConstraint — see the _Build comment on why that collapses
		-- to 0x0 here).
		local headerH = self._header.AbsoluteSize.Y
		if headerH > 0 then
			local size = math.clamp(headerH * 0.6, 18, 40)
			self._close.Size = UDim2.fromOffset(size, size)
		end
	end
end

return UIPanelComponent

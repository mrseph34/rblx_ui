--!strict
-- Owns the floating nav rail: the on-screen shortcut buttons (open shop, theme
-- editor, help, …) that behave like a regular game's "open shop" GUI buttons.
-- Rewritten as its own controller (was inline in ClientHandler) so the rail's
-- geometry math lives in one place and can be reasoned about/tested on its own.
--
-- Content (icons/labels/actions) comes from NavConfig; PLACEMENT (which side,
-- top/center/bottom, column vs toolbar, labelled or not) comes from whichever
-- is active: a UILayoutController preset, else the active pack's own Nav block.
--
-- Sizing is computed EXPLICITLY from the button list up front (not left to
-- AutomaticSize) so the rail's height is known before it's ever positioned —
-- that's what makes "Center" a true, deterministic vertical center instead of
-- an approximation that depends on layout resolving before the next read.
--
-- Vertical placement is computed in ABSOLUTE PIXELS from the camera's real
-- viewport size, not a Position scale-fraction. Confirmed via measurement that
-- even with ScreenGui.IgnoreGuiInset = true, EVERY Position (scale OR pixel
-- offset) still renders shifted up by exactly GuiService:GetGuiInset().Y (the
-- top bar) — a real, reproducible engine quirk in this environment, not a
-- one-off. Rather than fight it, we read the live inset and add it back in, so
-- the rail lands exactly where computed regardless of platform/inset size.
-- Re-centers automatically on viewport resize (window resize on PC, orientation
-- change on mobile) via a Changed listener.

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local NavConfig = require(script.Parent.Parent.Config.NavConfig)
local UIStyler = require(script.Parent.Parent.UIStyler)
local UIButtonComponent = require(script.Parent.Parent.Components.UIButtonComponent)

local UINavRailController = {}
UINavRailController.__index = UINavRailController

-- Fixed pixel clearance from the top/bottom screen edge (used for the Top/
-- Bottom vertical anchors) — a plain px margin is predictable across any
-- viewport size, unlike a scale fraction that shifts with aspect ratio.
local EDGE_MARGIN_Y = 70

function UINavRailController.new(themeController: any, screenController: any, layoutController: any, devConfig: any)
	local self = setmetatable({}, UINavRailController)
	self._themeController = themeController
	self._screenController = screenController
	self._layoutController = layoutController
	self._devConfig = devConfig
	self._player = Players.LocalPlayer
	self._gui = nil :: ScreenGui?
	self._actionHandler = nil :: ((string) -> ())?
	return self
end

-- ClientHandler wires this so button clicks route back through its navAction map.
function UINavRailController:SetActionHandler(fn: (action: string) -> ())
	self._actionHandler = fn
end

-- The buttons that should actually render (authorization-filtered).
function UINavRailController:_VisibleButtons(): { NavConfig.NavButton }
	local out = {}
	for _, def in NavConfig.Buttons do
		if not (def.authorizedOnly and not self._devConfig.IsAuthorized(self._player.UserId)) then
			table.insert(out, def)
		end
	end
	return out
end

-- Resolve the geometry to build with right now: the active layout preset if
-- one is set, else the active pack's own Nav block (via the layout controller,
-- which already knows how to fall back — see UILayoutController:GetNavGeometry).
function UINavRailController:_Geometry()
	local packNav = self._themeController:GetPack().Nav
	return self._layoutController:GetNavGeometry(packNav)
end

function UINavRailController:Build()
	if not self._devConfig.ShowNavRail then
		return
	end
	local playerGui = self._player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "NavRail"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	-- REQUIRED — this was the actual root cause of every "invisible icon" symptom.
	-- ScreenGui's true engine default is ZIndexBehavior.Global (confirmed by
	-- direct measurement — NOT Sibling, despite that being commonly assumed).
	-- Under Global, a descendant needs a HIGHER ZIndex than every ancestor to
	-- paint above it; Icon (ZIndex 1, nested inside Surface at ZIndex 2) was
	-- losing to its own ancestor and rendering fully behind it — invisible, no
	-- matter the text/font/size, confirmed by exhaustively ruling out every
	-- other candidate (font, weight, TextScaled, asset loading, capture tool).
	-- UIScreenBase already sets Sibling for every OTHER screen; this ScreenGui
	-- is built outside that base class, so it never inherited that fix.
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 8
	gui.Parent = playerGui
	self._gui = gui

	local geo = self:_Geometry()
	local buttons = self:_VisibleButtons()
	local horizontal = geo.fill == "Horizontal"
	local onRight = geo.side == "Right"

	-- Compute every button's size FIRST, so the rail's total content size (and
	-- therefore its true center) is known before anything is positioned.
	local sizes = {}
	local totalMain, maxCross = 0, 0
	for i, def in buttons do
		local size = NavConfig.SizeFor(def, geo.showLabels)
		sizes[i] = size
		local main = horizontal and size.X or size.Y
		local cross = horizontal and size.Y or size.X
		totalMain += main
		maxCross = math.max(maxCross, cross)
	end
	if #buttons > 1 then
		totalMain += NavConfig.Spacing * (#buttons - 1)
	end
	local railW = horizontal and totalMain or (maxCross + 16)
	local railH = horizontal and (maxCross + 16) or totalMain

	-- Vertical anchor, computed in ABSOLUTE PIXELS from the real viewport height,
	-- then compensated for the GuiInset quirk (see module-level note). Top/Bottom
	-- hug the edge with a fixed px margin; Center is a true pixel centre —
	-- AnchorPoint.Y = 0.5 at that exact Y, on a frame whose height we just
	-- computed exactly.
	local viewportH = workspace.CurrentCamera.ViewportSize.Y
	local insetY = GuiService:GetGuiInset().Y
	local anchorY, pixelY
	if geo.vertical == "Top" then
		anchorY, pixelY = 0, EDGE_MARGIN_Y + insetY
	elseif geo.vertical == "Bottom" then
		anchorY, pixelY = 1, viewportH - EDGE_MARGIN_Y + insetY
	else
		anchorY, pixelY = 0.5, viewportH * 0.5 + insetY
	end
	local edge = NavConfig.EdgeOffset

	local rail = UIStyler.Frame("Rail")
	rail.BackgroundTransparency = 1
	rail.AnchorPoint = Vector2.new(onRight and 1 or 0, anchorY)
	rail.Position = UDim2.new(onRight and 1 or 0, onRight and -edge or edge, 0, pixelY)
	rail.Size = UDim2.fromOffset(railW, railH)
	UIStyler.ListLayout({
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, NavConfig.Spacing),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}).Parent = rail
	rail.Parent = gui

	for i, def in buttons do
		local size = sizes[i]
		local showLabel = geo.showLabels and def.label ~= nil and def.label ~= ""
		local button = UIButtonComponent.new()
		button:Create(rail, {
			icon = def.icon,
			iconId = def.iconId,
			text = showLabel and def.label or nil,
			variant = def.variant or "Primary",
			size = UDim2.fromOffset(size.X, size.Y),
			layoutOrder = i,
			onClick = function()
				if self._actionHandler then
					self._actionHandler(def.action)
				end
			end,
		})
		self._screenController:RegisterHighlightTarget(def.id, button.Root)
	end
end

-- Tear down and rebuild — used after a pack swap or a layout-preset change,
-- since either can change the rail's side/vertical/labelled geometry.
function UINavRailController:Rebuild()
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	self:Build()
end

-- Keep the rail correctly placed across a window resize (PC) or orientation
-- change (mobile/tablet) — the pixel math in Build() is only right for the
-- viewport size at the moment it ran, so a real size change needs a rebuild.
function UINavRailController:WatchViewportResize()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		self:Rebuild()
	end)
end

return UINavRailController

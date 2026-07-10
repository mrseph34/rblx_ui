--!strict
-- Above-character billboard UI: a themed nameplate + vitals bars that float over
-- a character's head. One controller manages every plate it creates, re-skins
-- them all on a live theme swap, and lets you move a plate to a different
-- overhead location preset at runtime (SetLocation) — the "put the health bar /
-- overhead UI in a different spot, simply" ask, done as data + one call.
--
-- Usage (from a controller/handler with the theme controller):
--   local overhead = UIOverheadController.new(themeController)
--   overhead:Attach(character, { name = "Pip", level = 7 })
--   overhead:SetValues(character, { health = 80, mana = 40 })
--   overhead:SetLocation(character, "High")   -- move it
--   overhead:Detach(character)
--
-- It intentionally does NOT read Humanoid.Health itself — the game feeds values
-- via SetValues so the same plate works for players, NPCs and mobs alike.

local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local ThemeShape = require(script.Parent.Parent.ThemeShape)
local OverheadConfig = require(script.Parent.Parent.Config.OverheadConfig)

local UIOverheadController = {}
UIOverheadController.__index = UIOverheadController

export type OverheadController = typeof(setmetatable({} :: {
	_themeController: any,
	_plates: { [Instance]: any },
}, UIOverheadController))

function UIOverheadController.new(themeController: any): OverheadController
	local self = setmetatable({}, UIOverheadController)
	self._themeController = themeController
	self._plates = {}
	-- Live re-skin: repaint every plate when the theme changes.
	if themeController and themeController.ThemeChanged then
		themeController.ThemeChanged:Connect(function()
			self:_RestyleAll()
		end)
	end
	return self :: any
end

-- Find the part a billboard should adorn (Head for R6/R15, else the root).
local function adornPart(character: Instance): BasePart?
	if character:IsA("Model") then
		return (character:FindFirstChild("Head") :: BasePart?)
			or (character :: Model).PrimaryPart
			or (character:FindFirstChildWhichIsA("BasePart") :: BasePart?)
	end
	return character:IsA("BasePart") and character or nil
end

-- Build (or return the existing) plate for a character.
function UIOverheadController:Attach(character: Instance, info: { name: string?, level: number? }?)
	if self._plates[character] then
		self:_ApplyInfo(character, info)
		return
	end
	local part = adornPart(character)
	if not part then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OverheadUI"
	billboard.Adornee = part
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.ResetOnSpawn = false
	local rows = #OverheadConfig.Bars
	local height = (OverheadConfig.ShowNameplate and OverheadConfig.NameHeight or 0)
		+ rows * OverheadConfig.RowHeight
		+ 0.25
	billboard.Size = UDim2.fromScale(OverheadConfig.Width, height)
	billboard.StudsOffsetWorldSpace = OverheadConfig.Locations[OverheadConfig.DefaultLocation]

	-- Root surface (rounded, themed) holding a vertical stack.
	local surface = UIStyler.Frame("Surface")
	surface.BackgroundTransparency = 0.15
	surface.Size = UDim2.fromScale(1, 1)
	surface.Parent = billboard
	local corner = UIStyler.Corner(8)
	corner.Parent = surface
	local stroke = UIStyler.Stroke(Color3.new(), 1)
	stroke.Parent = surface
	UIStyler.Padding(4).Parent = surface
	UIStyler.ListLayout({ Padding = UDim.new(0, 2) }).Parent = surface

	local plate = {
		billboard = billboard,
		surface = surface,
		corner = corner,
		stroke = stroke,
		bars = {},
		name = nil :: TextLabel?,
		level = nil :: TextLabel?,
		location = OverheadConfig.DefaultLocation,
	}

	-- Name row (name + optional level chip).
	if OverheadConfig.ShowNameplate then
		local name = UIStyler.TextLabel("Name")
		name.Size = UDim2.new(1, 0, 0, 0)
		name.AutomaticSize = Enum.AutomaticSize.Y
		name.TextScaled = false
		name.TextSize = 16
		name.LayoutOrder = 0
		name.Parent = surface
		plate.name = name
	end

	-- Vitals bars.
	for i, barCfg in OverheadConfig.Bars do
		local track = UIStyler.Frame("bar_" .. barCfg.id)
		track.Size = UDim2.new(1, 0, 0, 8)
		track.LayoutOrder = i
		UIStyler.Corner(1000).Parent = track
		local fill = UIStyler.Frame("Fill")
		fill.Size = UDim2.fromScale(1, 1)
		fill.Parent = track
		UIStyler.Corner(1000).Parent = fill
		track.Parent = surface
		plate.bars[barCfg.id] = { track = track, fill = fill, cfg = barCfg }
	end

	billboard.Parent = part
	self._plates[character] = plate

	self:_ApplyInfo(character, info)
	self:_StylePlate(plate, self._themeController:GetTheme())

	-- Auto-clean when the character goes away.
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:Detach(character)
		end
	end)
end

function UIOverheadController:_ApplyInfo(character: Instance, info: { name: string?, level: number? }?)
	local plate = self._plates[character]
	if not plate or not info then
		return
	end
	if plate.name then
		local label = info.name or (character :: Instance).Name
		if OverheadConfig.ShowLevel and info.level then
			plate.name.Text = string.format("[%d] %s", info.level, label)
		else
			plate.name.Text = label
		end
	end
end

-- Feed values (0..maxValue) for any bar. Missing keys are left unchanged.
function UIOverheadController:SetValues(character: Instance, values: { [string]: number })
	local plate = self._plates[character]
	if not plate then
		return
	end
	for id, bar in plate.bars do
		local v = values[id]
		if v ~= nil then
			local max = bar.cfg.maxValue or 100
			bar.fill.Size = UDim2.fromScale(math.clamp(v / max, 0, 1), 1)
		end
	end
end

-- Move a plate to a different overhead location preset (Above/High/Front/…).
function UIOverheadController:SetLocation(character: Instance, locationId: string)
	local plate = self._plates[character]
	local offset = OverheadConfig.Locations[locationId]
	if not plate or not offset then
		return
	end
	plate.location = locationId
	plate.billboard.StudsOffsetWorldSpace = offset
end

function UIOverheadController:Detach(character: Instance)
	local plate = self._plates[character]
	if not plate then
		return
	end
	plate.billboard:Destroy()
	self._plates[character] = nil
end

function UIOverheadController:_RestyleAll()
	local theme = self._themeController:GetTheme()
	for _, plate in self._plates do
		self:_StylePlate(plate, theme)
	end
end

function UIOverheadController:_StylePlate(plate: any, theme: Types.UITheme)
	local c = theme.Colors
	local radius = ThemeShape.Radius(theme, theme.Radii.Medium)
	plate.surface.BackgroundColor3 = c.Surface
	plate.corner.CornerRadius = UDim.new(0, radius)
	plate.stroke.Color = c.Stroke
	plate.stroke.Thickness = theme.Effects.StrokeThickness
	plate.stroke.Transparency = 0.2
	if plate.name then
		plate.name.FontFace = theme.Fonts.Title
		plate.name.TextColor3 = c.TextPrimary
	end
	for _, bar in plate.bars do
		bar.track.BackgroundColor3 = c.Background
		bar.fill.BackgroundColor3 = (c :: any)[bar.cfg.colorToken] or c.Primary
	end
end

return UIOverheadController

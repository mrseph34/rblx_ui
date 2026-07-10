--!strict
-- Data-driven config for the above-character billboard UI (nameplate + vitals).
-- Decides which rows show, the bar order/colours, and the *location presets*
-- that place the billboard relative to the head — swapping location is a one-word
-- change here or a single UIOverheadController:SetLocation call at runtime.

local OverheadConfig = {}

-- StudsOffsetWorldSpace presets. Y is height above the attach part's center;
-- Z pushes it toward the camera-facing front. Pick per game feel.
OverheadConfig.Locations = {
	Above = Vector3.new(0, 2.6, 0), -- classic, just over the head
	High = Vector3.new(0, 3.6, 0), -- floats higher, good with big bars
	Head = Vector3.new(0, 1.9, 0), -- tight to the head
	Front = Vector3.new(0, 2.6, -1.4), -- tilted toward the viewer
	Feet = Vector3.new(0, -3.2, 0), -- ring-of-stats at the feet
}

OverheadConfig.DefaultLocation = "Above"

-- Which bars appear under the name, in order. Each maps a value key to a theme
-- colour token + icon. Drop or reorder rows to taste; add a bar by appending.
OverheadConfig.Bars = {
	{ id = "health", colorToken = "Error", icon = "❤️", maxValue = 100 },
	{ id = "mana", colorToken = "Primary", icon = "🔷", maxValue = 100 },
}

OverheadConfig.ShowNameplate = true
OverheadConfig.ShowLevel = true

-- Billboard sizing (studs). Width scales the plate; height grows with bar count.
OverheadConfig.Width = 4.4
OverheadConfig.RowHeight = 0.42
OverheadConfig.NameHeight = 0.7

return OverheadConfig

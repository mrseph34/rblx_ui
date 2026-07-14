--!strict
-- DEV PREVIEW (auto-runs as a LocalScript, Studio-only). Shows the bar-for-bar
-- reference screen reproductions so they can be eyeballed against the source
-- screenshots.
--
-- An always-visible switcher bar sits at the top of the screen with a button per
-- screen + Hide. The Store auto-opens on Play so the reproduction is visible
-- immediately. Number keys 1..5 / 0 still work. Self-contained; does NOT touch
-- the main ClientHandler UI.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Dev-only: never render the preview for live players.
if not RunService:IsStudio() then
	return
end

local UI = script.Parent.UI
local Reference = UI.Reference
local RefExclusiveStore = require(Reference.RefExclusiveStore)
local RefServersShop = require(Reference.RefServersShop)
local RefSettings = require(Reference.RefSettings)
local RefIndex = require(Reference.RefIndex)
local RefHUD = require(Reference.RefHUD)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "RefPreview"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5000 -- above the game's own UI
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Dim backdrop + a stage the current screen builds into (both hidden until a
-- screen is shown; the switcher bar below stays visible always).
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(10, 20, 40)
backdrop.BackgroundTransparency = 0.4
backdrop.BorderSizePixel = 0
backdrop.Active = true -- swallow clicks so the game behind isn't touched
backdrop.Visible = false
backdrop.ZIndex = 1
backdrop.Parent = gui

local stage = Instance.new("Frame")
stage.Name = "Stage"
stage.BackgroundTransparency = 1
stage.Size = UDim2.fromScale(1, 1)
stage.Visible = false
stage.ZIndex = 2
stage.Parent = gui

-- ---- switcher bar (always visible) ------------------------------------
local bar = Instance.new("Frame")
bar.Name = "Switcher"
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.new(0.5, 0, 0, 6)
bar.Size = UDim2.fromOffset(720, 40)
bar.BackgroundColor3 = Color3.fromRGB(18, 30, 54)
bar.BorderSizePixel = 0
bar.ZIndex = 50
bar.Parent = gui
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 10)
barCorner.Parent = bar
local barPad = Instance.new("UIPadding")
barPad.PaddingLeft = UDim.new(0, 8)
barPad.PaddingRight = UDim.new(0, 8)
barPad.PaddingTop = UDim.new(0, 5)
barPad.PaddingBottom = UDim.new(0, 5)
barPad.Parent = bar
local barLayout = Instance.new("UIListLayout")
barLayout.FillDirection = Enum.FillDirection.Horizontal
barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
barLayout.Padding = UDim.new(0, 6)
barLayout.SortOrder = Enum.SortOrder.LayoutOrder
barLayout.Parent = bar

local function barButton(text: string, order: number, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(text == "REF PREVIEW ▸" and 118 or 92, 30)
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.Text = text
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	b.TextSize = 14
	b.LayoutOrder = order
	b.ZIndex = 51
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 7)
	c.Parent = b
	b.Parent = bar
	return b
end

-- key -> { name, build(parent) }
local screens = {
	{ key = Enum.KeyCode.One, name = "1 Store", build = RefExclusiveStore.build },
	{ key = Enum.KeyCode.Two, name = "2 Shop", build = RefServersShop.build },
	{ key = Enum.KeyCode.Three, name = "3 Settings", build = RefSettings.build },
	{ key = Enum.KeyCode.Four, name = "4 Index", build = RefIndex.build },
	{ key = Enum.KeyCode.Five, name = "5 HUD", build = RefHUD.build },
}

local function hide()
	backdrop.Visible = false
	stage.Visible = false
	stage:ClearAllChildren()
end

local function show(entry: { name: string, build: (Instance) -> any })
	stage:ClearAllChildren()
	backdrop.Visible = true
	stage.Visible = true
	local ok, result = pcall(entry.build, stage)
	if not ok then
		local err = Instance.new("TextLabel")
		err.Size = UDim2.fromScale(0.9, 0.4)
		err.Position = UDim2.fromScale(0.5, 0.5)
		err.AnchorPoint = Vector2.new(0.5, 0.5)
		err.BackgroundColor3 = Color3.fromRGB(25, 0, 0)
		err.TextColor3 = Color3.fromRGB(255, 140, 140)
		err.FontFace = Font.fromEnum(Enum.Font.Code)
		err.TextSize = 22
		err.TextWrapped = true
		err.TextXAlignment = Enum.TextXAlignment.Left
		err.TextYAlignment = Enum.TextYAlignment.Top
		err.Text = "BUILD ERROR (" .. entry.name .. "):\n" .. tostring(result)
		err.ZIndex = 100
		err.Parent = stage
		warn("[RefPreview] build error:", result)
	else
		if result and result.close then
			result.close.Activated:Connect(hide)
		end
	end
	print("[RefPreview] showing:", entry.name)
end

barButton("REF PREVIEW ▸", 0, Color3.fromRGB(60, 90, 150)).AutoButtonColor = false
for i, entry in screens do
	barButton(entry.name, i, Color3.fromRGB(46, 122, 210)).Activated:Connect(function()
		show(entry)
	end)
end
barButton("Hide", #screens + 1, Color3.fromRGB(196, 66, 66)).Activated:Connect(hide)

-- Keyboard shortcuts (still handy).
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Zero then
		hide()
		return
	end
	for _, entry in screens do
		if input.KeyCode == entry.key then
			show(entry)
			return
		end
	end
end)

-- Start HIDDEN so Play shows the real game UI (the Standard theme + pack), not a
-- reference overlay on top of it. Pull up any reference on demand from the top
-- switcher bar (or number keys 1-5; 0 to hide). Previously this auto-opened the
-- Store on Play, which sat on top of the real UI at DisplayOrder 5000 and made it
-- look like the game hadn't changed.

print("[RefPreview] Reference preview loaded (hidden) — use the bar at the top of the screen (or keys 1-5, 0 to hide) to compare against the reference screens.")

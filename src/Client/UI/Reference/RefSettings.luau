--!strict
-- Reference "settings" (dark, TRANSLUCENT): option rows where the first two are
-- functional toggle SLIDERS and the last is a button. TEMPLATE text. Every
-- element is the shared nested box (dark border -> light gap -> gradient inner).

local TweenService = game:GetService("TweenService")

local RefSkin = require(script.Parent.RefSkin)
local C = RefSkin.C
local RefSettings = {}

local ROW_LIGHT = Color3.fromRGB(78, 108, 146)

local function settingRow(parent: Instance, y: number, icon: string): Frame
	local _, inner = RefSkin.box(parent, {
		size = UDim2.fromScale(0.9, 0.22), position = UDim2.fromScale(0.5, y), anchor = Vector2.new(0.5, 0),
		gradTop = C.SetRowTop, gradBottom = C.SetRowBottom, border = C.SetRowBorder, lightBg = ROW_LIGHT, gap = 4, zindex = 4,
	})
	RefSkin.label(inner, icon, {
		size = UDim2.fromScale(0.1, 0.6), position = UDim2.fromScale(0.04, 0.5), anchor = Vector2.new(0, 0.5),
		outline = 0, textSize = 40, zindex = 6,
	})
	RefSkin.label(inner, "Option", {
		size = UDim2.fromScale(0.5, 0.5), position = UDim2.fromScale(0.15, 0.5), anchor = Vector2.new(0, 0.5),
		align = Enum.TextXAlignment.Left, color = C.White, outline = 3, textSize = 34, zindex = 6,
	})
	return inner
end

local function toggleControl(row: Frame)
	local _, track = RefSkin.box(row, {
		size = UDim2.fromScale(0.3, 0.62), position = UDim2.fromScale(0.97, 0.5), anchor = Vector2.new(1, 0.5),
		gradTop = Color3.fromRGB(150, 158, 168), gradBottom = Color3.fromRGB(120, 128, 138),
		border = Color3.fromRGB(96, 102, 112), lightBg = Color3.fromRGB(196, 202, 210), studs = false, gap = 3, zindex = 5,
	})

	local knobOuter, knobInner = RefSkin.box(track, {
		button = true, size = UDim2.fromScale(0.46, 0.84), position = UDim2.fromScale(0.27, 0.5), anchor = Vector2.new(0.5, 0.5),
		gradTop = Color3.fromRGB(236, 86, 86), gradBottom = C.Red, border = C.RedDark, lightBg = Color3.fromRGB(252, 214, 214), studs = false, gap = 2, zindex = 6,
	})
	local lbl = RefSkin.label(knobInner, "OFF", { color = C.White, outline = 2.5, textSize = 24, zindex = 8 })
	local grad = knobInner:FindFirstChildOfClass("UIGradient")

	local on = false
	knobOuter.Activated:Connect(function()
		on = not on
		TweenService:Create(knobOuter, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = on and UDim2.fromScale(0.73, 0.5) or UDim2.fromScale(0.27, 0.5),
		}):Play()
		if grad then
			grad.Color = on and ColorSequence.new(Color3.fromRGB(108, 214, 92), Color3.fromRGB(72, 176, 56))
				or ColorSequence.new(Color3.fromRGB(236, 86, 86), C.Red)
		end
		lbl.Text = on and "ON" or "OFF"
	end)
end

local function buttonControl(row: Frame)
	local _, inner = RefSkin.box(row, {
		button = true, size = UDim2.fromScale(0.28, 0.62), position = UDim2.fromScale(0.97, 0.5), anchor = Vector2.new(1, 0.5),
		gradTop = C.GrayTop, gradBottom = C.GrayBottom, border = C.GrayBottom, lightBg = Color3.fromRGB(214, 220, 228), studs = false, gap = 3, zindex = 5,
	})
	RefSkin.label(inner, "Button", { color = C.White, outline = 2.5, textSize = 26, zindex = 7 })
end

function RefSettings.build(parent: Instance): RefSkin.Modal
	local modal = RefSkin.Modal({
		parent = parent, title = "Settings Title", aspect = 1.62, widthScale = 0.5, dark = true, transparency = 0.15,
	})
	local body = modal.body

	toggleControl(settingRow(body, 0.08, "🎵"))
	toggleControl(settingRow(body, 0.4, "🔊"))
	buttonControl(settingRow(body, 0.72, "📋"))

	return modal
end

return RefSettings

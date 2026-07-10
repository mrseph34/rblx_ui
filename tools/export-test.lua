-- Headless smoke test for PackExporter + theme Shape round-trip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Locate the UI tree (mirrors default.project.json: Client mounts as ClientHandler).
local scripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
local clientRoot = scripts and scripts:FindFirstChild("ClientHandler")
local UI = clientRoot and clientRoot:FindFirstChild("UI")
assert(UI, "UI folder not found")

local PackExporter = require(UI.PackExporter)
local UIThemeConfig = require(UI.Config.UIThemeConfig)
local UIPackConfig = require(UI.Config.UIPackConfig)
local ThemeSerializer = require(UI.Themes.ThemeSerializer)

local theme = UIThemeConfig.Themes[1]
local pack = UIPackConfig.Packs[1]

local ok = true
for _, part in PackExporter.Parts do
	local success, result = pcall(PackExporter.Export, part.id, theme, pack)
	if success then
		print(string.format("[OK] export %-10s -> %d chars", part.id, #result))
	else
		ok = false
		warn(string.format("[FAIL] export %s: %s", part.id, tostring(result)))
	end
end

-- Shape round-trip: serialize SciFi (Raised3D) and deserialize, check Style.
local sci
for _, t in UIThemeConfig.Themes do
	if t.Id == "SciFi" then sci = t end
end
if sci then
	local src = ThemeSerializer.Serialize(sci)
	local back = ThemeSerializer.Deserialize(src, theme)
	if back and back.Shape and back.Shape.Style == "Raised3D" then
		print("[OK] Shape round-trip preserved Raised3D, roundness=" .. tostring(back.Shape.RoundnessScale))
	else
		ok = false
		warn("[FAIL] Shape round-trip lost Style; got " .. tostring(back and back.Shape and back.Shape.Style))
	end
end

print("[SMOKE] themes=" .. #UIThemeConfig.Themes .. " packs=" .. #UIPackConfig.Packs)
print(ok and "[SMOKE] ALL PASS" or "[SMOKE] FAILURES ABOVE")

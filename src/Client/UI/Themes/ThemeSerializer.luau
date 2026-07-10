--!strict
-- Round-trips a live UITheme table to/from Luau module source.
--
-- Serialize() is what the in-game Theme Editor's Export button calls: it emits
-- a module that is byte-for-byte compatible with the hand-written theme files
-- in this folder (see DefaultTheme). Paste that text into a new file under
-- Client/UI/Themes and register it — or hand it to a developer verbatim.
--
-- Deserialize() closes the loop: it parses an exported block back into a live
-- theme so the editor's Import can preview pasted source without a rebuild.
-- It intentionally understands only the value forms Serialize() produces
-- (Color3.fromRGB, Font.fromEnum, TweenInfo.new, numbers, booleans, strings) —
-- it is not a general Luau evaluator.

local Types = require(script.Parent.Parent.Types)

local ThemeSerializer = {}

-- ========================================================================
-- Serialize
-- ========================================================================

local function color(c: Color3): string
	return string.format(
		"Color3.fromRGB(%d, %d, %d)",
		math.round(c.R * 255),
		math.round(c.G * 255),
		math.round(c.B * 255)
	)
end

-- Recover the Enum.Font name from a Font so exports read like the hand-written
-- themes (Font.fromEnum(Enum.Font.GothamBold)) instead of a raw content id.
local function font(f: Font): string
	for _, item in Enum.Font:GetEnumItems() do
		if item ~= Enum.Font.Unknown then
			local ok, candidate = pcall(Font.fromEnum, item)
			if ok and candidate.Family == f.Family and candidate.Weight == f.Weight and candidate.Style == f.Style then
				return string.format("Font.fromEnum(Enum.Font.%s)", item.Name)
			end
		end
	end
	-- Fallback: reconstruct from raw family/weight/style.
	return string.format(
		'Font.new("%s", Enum.FontWeight.%s, Enum.FontStyle.%s)',
		f.Family,
		f.Weight.Name,
		f.Style.Name
	)
end

local function tween(t: TweenInfo): string
	return string.format(
		"TweenInfo.new(%s, Enum.EasingStyle.%s, Enum.EasingDirection.%s)",
		tostring(t.Time),
		t.EasingStyle.Name,
		t.EasingDirection.Name
	)
end

local function num(n: number): string
	if n == math.floor(n) then
		return tostring(math.floor(n))
	end
	return tostring(n)
end

local function indentBlock(lines: { string }): string
	return table.concat(lines, "\n")
end

-- Emit a `Name = value,` line at a given indent depth.
local function line(depth: number, key: string, value: string): string
	return string.rep("\t", depth) .. key .. " = " .. value .. ","
end

function ThemeSerializer.Serialize(theme: Types.UITheme): string
	local c = theme.Colors
	local f = theme.Fonts
	local ts = theme.TextSizes
	local r = theme.Radii
	local sp = theme.Spacing
	local a = theme.Animations
	local e = theme.Effects

	-- Sanitise the id into a valid, unique-ish variable/module name.
	local varName = (string.gsub(theme.DisplayName, "[^%w]", "")) .. "Theme"
	if varName == "Theme" then
		varName = "CustomTheme"
	end

	local lines = {
		"--!strict",
		"-- Exported from the in-game Theme Editor. Drop this file into",
		"-- Client/UI/Themes and register it in UIThemeConfig to use it.",
		"",
		"local Types = require(script.Parent.Parent.Types)",
		"",
		string.format("local %s: Types.UITheme = {", varName),
		line(1, "Id", string.format("%q", theme.Id)),
		line(1, "DisplayName", string.format("%q", theme.DisplayName)),
		"",
		"\tColors = {",
		line(2, "Primary", color(c.Primary)),
		line(2, "Secondary", color(c.Secondary)),
		line(2, "Accent", color(c.Accent)),
		line(2, "Background", color(c.Background)),
		line(2, "Surface", color(c.Surface)),
		line(2, "SurfaceRaised", color(c.SurfaceRaised)),
		line(2, "Success", color(c.Success)),
		line(2, "Warning", color(c.Warning)),
		line(2, "Error", color(c.Error)),
		line(2, "TextPrimary", color(c.TextPrimary)),
		line(2, "TextSecondary", color(c.TextSecondary)),
		line(2, "TextOnPrimary", color(c.TextOnPrimary)),
		line(2, "Stroke", color(c.Stroke)),
		line(2, "Overlay", color(c.Overlay)),
		line(2, "Disabled", color(c.Disabled)),
		"\t},",
		"",
		"\tFonts = {",
		line(2, "Title", font(f.Title)),
		line(2, "Subtitle", font(f.Subtitle)),
		line(2, "Body", font(f.Body)),
		line(2, "Button", font(f.Button)),
		line(2, "Numeric", font(f.Numeric)),
		"\t},",
		"",
		"\tTextSizes = {",
		line(2, "Title", num(ts.Title)),
		line(2, "Subtitle", num(ts.Subtitle)),
		line(2, "Body", num(ts.Body)),
		line(2, "Button", num(ts.Button)),
		line(2, "Small", num(ts.Small)),
		"\t},",
		"",
		"\tRadii = {",
		line(2, "Small", num(r.Small)),
		line(2, "Medium", num(r.Medium)),
		line(2, "Large", num(r.Large)),
		line(2, "Pill", num(r.Pill)),
		"\t},",
		"",
		"\tSpacing = {",
		line(2, "XS", num(sp.XS)),
		line(2, "S", num(sp.S)),
		line(2, "M", num(sp.M)),
		line(2, "L", num(sp.L)),
		line(2, "XL", num(sp.XL)),
		"\t},",
		"",
		"\tAnimations = {",
		line(2, "Appear", tween(a.Appear)),
		line(2, "Disappear", tween(a.Disappear)),
		line(2, "Hover", tween(a.Hover)),
		line(2, "Press", tween(a.Press)),
		line(2, "Emphasis", tween(a.Emphasis)),
		line(2, "ThemeSwap", tween(a.ThemeSwap)),
		"\t},",
		"",
		"\tEffects = {",
		line(2, "UseGradients", tostring(e.UseGradients)),
		line(2, "GradientIntensity", num(e.GradientIntensity)),
		line(2, "ShadowTransparency", num(e.ShadowTransparency)),
		line(2, "HoverScale", num(e.HoverScale)),
		line(2, "PressScale", num(e.PressScale)),
		line(2, "StrokeThickness", num(e.StrokeThickness)),
		"\t},",
	}

	-- Shape is optional; emit it only when present so Flat themes stay minimal.
	local shape = theme.Shape
	if shape then
		table.insert(lines, "")
		table.insert(lines, "\tShape = {")
		table.insert(lines, line(2, "RoundnessScale", num(shape.RoundnessScale)))
		table.insert(lines, line(2, "Style", string.format("%q", shape.Style)))
		table.insert(lines, line(2, "Depth", num(shape.Depth)))
		table.insert(lines, line(2, "HighlightTransparency", num(shape.HighlightTransparency)))
		table.insert(lines, line(2, "ShadowStrength", num(shape.ShadowStrength)))
		table.insert(lines, line(2, "Bounce", num(shape.Bounce)))
		table.insert(lines, "\t},")
	end

	table.insert(lines, "}")
	table.insert(lines, "")
	table.insert(lines, string.format("return %s", varName))
	table.insert(lines, "")

	return indentBlock(lines)
end

-- ========================================================================
-- Deserialize
-- ========================================================================

-- Grab the first occurrence of a `Key = <value>,` pair anywhere in the source.
-- Keys are unique enough across the theme table that a flat search is fine.
local function grab(source: string, key: string): string?
	local value = string.match(source, key .. "%s*=%s*([^\n]-),%s*\n")
	if value then
		return (string.gsub(value, "%s+$", ""))
	end
	return nil
end

local function parseColor(source: string, key: string, fallback: Color3): Color3
	local raw = grab(source, key)
	if raw then
		local rr, gg, bb = string.match(raw, "Color3%.fromRGB%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)")
		if rr then
			return Color3.fromRGB(tonumber(rr) :: number, tonumber(gg) :: number, tonumber(bb) :: number)
		end
	end
	return fallback
end

local function parseNumber(source: string, key: string, fallback: number): number
	local raw = grab(source, key)
	return raw and tonumber(raw) or fallback
end

local function parseBool(source: string, key: string, fallback: boolean): boolean
	local raw = grab(source, key)
	if raw == "true" then
		return true
	elseif raw == "false" then
		return false
	end
	return fallback
end

local function parseFont(source: string, key: string, fallback: Font): Font
	local raw = grab(source, key)
	if raw then
		local enumName = string.match(raw, "Enum%.Font%.(%w+)")
		if enumName and (Enum.Font :: any)[enumName] then
			return Font.fromEnum((Enum.Font :: any)[enumName])
		end
	end
	return fallback
end

local function parseTween(source: string, key: string, fallback: TweenInfo): TweenInfo
	local raw = grab(source, key)
	if raw then
		local time, style, dir = string.match(
			raw,
			"TweenInfo%.new%(%s*([%d%.]+)%s*,%s*Enum%.EasingStyle%.(%w+)%s*,%s*Enum%.EasingDirection%.(%w+)"
		)
		if time then
			local easingStyle = (Enum.EasingStyle :: any)[style]
			local easingDir = (Enum.EasingDirection :: any)[dir]
			if easingStyle and easingDir then
				return TweenInfo.new(tonumber(time) :: number, easingStyle, easingDir)
			end
		end
	end
	return fallback
end

-- Parse exported source into a theme, layering onto `base` (usually the
-- current DefaultTheme) so any token the source omits keeps a sane value.
-- Returns nil + reason if the block is clearly not a theme export.
function ThemeSerializer.Deserialize(source: string, base: Types.UITheme): (Types.UITheme?, string?)
	if not string.find(source, "Colors") or not string.find(source, "Primary") then
		return nil, "That doesn't look like an exported theme (no Colors block found)."
	end

	local id = grab(source, "Id")
	local displayName = grab(source, "DisplayName")
	local function unquote(s: string?): string?
		return s and (string.match(s, '^"(.*)"$') or string.match(s, "^'(.*)'$")) or s
	end

	local c = base.Colors
	local f = base.Fonts
	local ts = base.TextSizes
	local r = base.Radii
	local sp = base.Spacing
	local a = base.Animations
	local e = base.Effects

	local theme: Types.UITheme = {
		Id = unquote(id) or "Custom",
		DisplayName = unquote(displayName) or "Custom",
		Colors = {
			Primary = parseColor(source, "Primary", c.Primary),
			Secondary = parseColor(source, "Secondary", c.Secondary),
			Accent = parseColor(source, "Accent", c.Accent),
			Background = parseColor(source, "Background", c.Background),
			Surface = parseColor(source, "Surface", c.Surface),
			SurfaceRaised = parseColor(source, "SurfaceRaised", c.SurfaceRaised),
			Success = parseColor(source, "Success", c.Success),
			Warning = parseColor(source, "Warning", c.Warning),
			Error = parseColor(source, "Error", c.Error),
			TextPrimary = parseColor(source, "TextPrimary", c.TextPrimary),
			TextSecondary = parseColor(source, "TextSecondary", c.TextSecondary),
			TextOnPrimary = parseColor(source, "TextOnPrimary", c.TextOnPrimary),
			Stroke = parseColor(source, "Stroke", c.Stroke),
			Overlay = parseColor(source, "Overlay", c.Overlay),
			Disabled = parseColor(source, "Disabled", c.Disabled),
		},
		Fonts = {
			Title = parseFont(source, "Title", f.Title),
			Subtitle = parseFont(source, "Subtitle", f.Subtitle),
			Body = parseFont(source, "Body", f.Body),
			Button = parseFont(source, "Button", f.Button),
			Numeric = parseFont(source, "Numeric", f.Numeric),
		},
		TextSizes = {
			Title = parseNumber(source, "Title", ts.Title),
			Subtitle = parseNumber(source, "Subtitle", ts.Subtitle),
			Body = parseNumber(source, "Body", ts.Body),
			Button = parseNumber(source, "Button", ts.Button),
			Small = parseNumber(source, "Small", ts.Small),
		},
		Radii = {
			Small = parseNumber(source, "Small", r.Small),
			Medium = parseNumber(source, "Medium", r.Medium),
			Large = parseNumber(source, "Large", r.Large),
			Pill = parseNumber(source, "Pill", r.Pill),
		},
		Spacing = {
			XS = parseNumber(source, "XS", sp.XS),
			S = parseNumber(source, "S", sp.S),
			M = parseNumber(source, "M", sp.M),
			L = parseNumber(source, "L", sp.L),
			XL = parseNumber(source, "XL", sp.XL),
		},
		Animations = {
			Appear = parseTween(source, "Appear", a.Appear),
			Disappear = parseTween(source, "Disappear", a.Disappear),
			Hover = parseTween(source, "Hover", a.Hover),
			Press = parseTween(source, "Press", a.Press),
			Emphasis = parseTween(source, "Emphasis", a.Emphasis),
			ThemeSwap = parseTween(source, "ThemeSwap", a.ThemeSwap),
		},
		Effects = {
			UseGradients = parseBool(source, "UseGradients", e.UseGradients),
			GradientIntensity = parseNumber(source, "GradientIntensity", e.GradientIntensity),
			ShadowTransparency = parseNumber(source, "ShadowTransparency", e.ShadowTransparency),
			HoverScale = parseNumber(source, "HoverScale", e.HoverScale),
			PressScale = parseNumber(source, "PressScale", e.PressScale),
			StrokeThickness = parseNumber(source, "StrokeThickness", e.StrokeThickness),
		},
	}

	-- Shape round-trips only if the source has a Shape block (Style key present);
	-- otherwise carry the base theme's Shape so imports of Flat exports stay Flat.
	if string.find(source, "Shape") and string.find(source, "Style") then
		local styleRaw = grab(source, "Style")
		local style = (styleRaw and (string.match(styleRaw, '^"(.*)"$') or string.match(styleRaw, "^'(.*)'$"))) or "Flat"
		theme.Shape = {
			RoundnessScale = parseNumber(source, "RoundnessScale", 1),
			Style = style :: any,
			Depth = parseNumber(source, "Depth", 0),
			HighlightTransparency = parseNumber(source, "HighlightTransparency", 1),
			ShadowStrength = parseNumber(source, "ShadowStrength", 0),
			Bounce = parseNumber(source, "Bounce", 0),
		}
	else
		theme.Shape = base.Shape
	end

	return theme, nil
end

return ThemeSerializer

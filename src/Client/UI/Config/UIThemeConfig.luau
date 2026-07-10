--!strict
-- The theme registry. Requires every theme module and exposes them by id, plus
-- the default id used at boot. Adding a theme = drop a module in Themes/ and
-- add one line here; nothing else in the system needs to change.
--
-- The in-game Theme Editor can also register runtime-only themes (imported or
-- edited) directly on UIThemeController without touching this file.

local Themes = script.Parent.Parent.Themes
local Types = require(script.Parent.Parent.Types)
local StyleThemes = require(Themes.StyleThemes)

local UIThemeConfig = {}

UIThemeConfig.DefaultThemeId = "Default"

-- The four hand-authored, colour-led themes first, then the generated batch of
-- shape/feel style variants (Flat / Bubbly / Raised3D). Both kinds are plain
-- Types.UITheme, so the rest of the system treats them identically.
UIThemeConfig.Themes = {
	require(Themes.DefaultTheme),
	require(Themes.CartoonTheme),
	require(Themes.RusticTheme),
	require(Themes.SciFiTheme),
} :: { Types.UITheme }

for _, theme in StyleThemes.Themes do
	table.insert(UIThemeConfig.Themes, theme)
end

function UIThemeConfig.GetById(id: string): Types.UITheme?
	for _, theme in UIThemeConfig.Themes do
		if theme.Id == id then
			return theme
		end
	end
	return nil
end

return UIThemeConfig

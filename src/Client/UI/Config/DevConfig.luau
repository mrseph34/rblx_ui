--!strict
-- Dev-only flags. Gates the Theme Editor / selector behind a keybind or a
-- userId allowlist so it doesn't ship to live players. During MVP everything
-- is on; tighten before release by setting ThemeEditorEnabled = false or
-- filling AuthorizedUserIds.

local DevConfig = {}

-- Master switch for the in-game Theme Editor + selector.
DevConfig.ThemeEditorEnabled = true

-- If non-empty, only these userIds may open the Theme Editor (even when the
-- keybind fires). Empty = allow everyone (MVP default).
DevConfig.AuthorizedUserIds = {} :: { number }

-- Show the floating nav rail with shop/HUD/theme shortcuts.
DevConfig.ShowNavRail = true

-- Auto-start the tutorial on join.
DevConfig.AutoStartTutorial = true

function DevConfig.IsAuthorized(userId: number): boolean
	if not DevConfig.ThemeEditorEnabled then
		return false
	end
	if #DevConfig.AuthorizedUserIds == 0 then
		return true
	end
	return table.find(DevConfig.AuthorizedUserIds, userId) ~= nil
end

return DevConfig

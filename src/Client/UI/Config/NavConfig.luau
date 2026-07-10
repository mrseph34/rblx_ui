--!strict
-- Configures the floating nav rail — the on-screen shortcut buttons (open shop,
-- theme editor, help, …) that behave like a regular game's "open shop" GUI
-- buttons. Everything about their look and placement is data here: button size,
-- shape, spacing, which corner/side the rail hugs, and the per-button list.
--
-- The rail's side/vertical anchor still comes from the active pack (pack.Nav) so
-- packs can relocate it for a different feel; this config layers the *geometry*
-- (size/spacing/offset) and the *button set* on top. Change a size or add a
-- button here — no handler code edits.

local NavConfig = {}

-- Rail geometry. ButtonSize is per-button (square by default); FillDirection
-- lets the rail be a vertical column (classic) or a horizontal toolbar.
NavConfig.ButtonSize = Vector2.new(56, 56)
NavConfig.Spacing = 10
NavConfig.EdgeOffset = 12 -- px gap from the screen edge
NavConfig.FillDirection = "Vertical" :: "Vertical" | "Horizontal"

-- Per-button definitions. `id` is stable (used as a highlight target for the
-- tutorial), `icon` is an emoji placeholder, `action` names what it does (the
-- handler maps these), `authorizedOnly` hides dev tools from live players.
export type NavButton = {
	id: string,
	icon: string,
	action: string,
	authorizedOnly: boolean?,
	-- Optional per-button size override (e.g. a bigger primary shop button).
	size: Vector2?,
	variant: string?,
}

NavConfig.Buttons = {
	{ id = "nav.shop", icon = "🛒", action = "ToggleShop", variant = "Primary", size = Vector2.new(64, 64) },
	{ id = "nav.settings", icon = "⚙️", action = "ToggleSettings", variant = "Ghost" },
	{ id = "nav.theme", icon = "🎨", action = "ToggleThemeEditor", authorizedOnly = true, variant = "Secondary" },
	{ id = "nav.help", icon = "❓", action = "ShowTutorial", variant = "Ghost" },
} :: { NavButton }

return NavConfig

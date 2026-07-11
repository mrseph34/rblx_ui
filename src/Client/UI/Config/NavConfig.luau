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

-- Rail geometry. ButtonSize is the SQUARE size for icon-only buttons;
-- LabeledButtonSize is the wider size used automatically for any button that
-- carries a text `label` (icon+text or text-only). FillDirection lets the rail
-- be a vertical column (classic) or a horizontal toolbar.
NavConfig.ButtonSize = Vector2.new(56, 56)
NavConfig.LabeledButtonSize = Vector2.new(150, 46)
NavConfig.Spacing = 10
NavConfig.EdgeOffset = 12 -- px gap from the screen edge
NavConfig.FillDirection = "Vertical" :: "Vertical" | "Horizontal"

-- Global toggle: false = ignore every button's `label` and render the whole
-- rail as compact icon-only squares (flip this one flag for the minimal look).
NavConfig.ShowLabels = true

-- Per-button definitions. Each button can show an emoji `icon`, an `iconId`
-- image, a text `label`, or any combination — that's the "emoji, text, or
-- both" the rail supports out of the box:
--   icon only            -> { icon = "🛒" }
--   text only            -> { label = "Shop" }
--   icon + text          -> { icon = "🛒", label = "Shop" }
--   image (asset) + text -> { iconId = "rbxassetid://123", label = "Shop" }
-- `id` is stable (a highlight target for the tutorial), `action` names what it
-- does (the handler maps these), `authorizedOnly` hides dev tools from live
-- players. A button is icon-only (square) unless it has a `label` AND
-- ShowLabels is on, in which case it uses LabeledButtonSize.
export type NavButton = {
	id: string,
	action: string,
	-- Content: any mix of these three (at least one). icon = emoji placeholder,
	-- iconId = image asset id, label = text shown beside/instead of the icon.
	icon: string?,
	iconId: string?,
	label: string?,
	authorizedOnly: boolean?,
	-- Optional per-button size override (e.g. a bigger primary shop button).
	size: Vector2?,
	variant: string?,
}

NavConfig.Buttons = {
	{ id = "nav.shop", icon = "🛒", label = "Shop", action = "ToggleShop", variant = "Primary" },
	{ id = "nav.settings", icon = "⚙️", label = "Settings", action = "ToggleSettings", variant = "Ghost" },
	{ id = "nav.theme", icon = "🎨", label = "Theme Editor", action = "ToggleThemeEditor", authorizedOnly = true, variant = "Secondary" },
	{ id = "nav.help", icon = "❓", label = "Help", action = "ShowTutorial", variant = "Ghost" },
} :: { NavButton }

-- The size a button should render at: the wide labelled size when labels are on
-- AND it has a label, else its square override or the default square size.
-- `showLabels` lets a layout preset override the NavConfig global per rebuild;
-- pass nil to use the global.
function NavConfig.SizeFor(button: NavButton, showLabels: boolean?): Vector2
	local labelsOn = showLabels
	if labelsOn == nil then
		labelsOn = NavConfig.ShowLabels
	end
	if labelsOn and button.label and button.label ~= "" then
		return NavConfig.LabeledButtonSize
	end
	return button.size or NavConfig.ButtonSize
end

return NavConfig

# rblx_ui — modular, data-driven, theme-able Roblox UI pack

A drop-in UI library for any Roblox game: shop, HUD, tutorial, modals, a
reusable animated component base, and an **in-game Theme Editor** that lets you
restyle everything live and **export the result as a ready-to-paste Luau theme
module**.

Everything is script-driven, responsive (Scale/AnchorPoint), and data-driven —
screens render from config, not hardcoded instances. Adding a feature means
adding one properly-placed ModuleScript, not editing unrelated files.

## Module tree

```
ReplicatedStorage/Shared
  Types                         schemas shared by server + client
  Config/ShopConfig             currencies, categories, items, price helpers (source of truth)
  Net/Remotes                   remote names + create/wait helpers

ServerScriptService/ServerHandler   (the ONE server Script)
  Services/ShopService          authoritative purchase validation

StarterPlayerScripts/ClientHandler  (the ONE client LocalScript — boots everything)
  UI
    Types                       theme/pack/component/screen schemas
    UISignal                    tiny signal primitive
    UIStyler                    low-level GuiObject builders (only place raw Instance.new lives)

    Config
      TextConfig                localization seam (textKey -> string)
      UIThemeConfig             theme registry (+ default id)
      UIPackConfig              layout packs (grid/list shop, compact/large HUD, ...)
      HUDConfig                 declarative HUD element list
      TutorialConfig            step-based onboarding data
      InputConfig               cross-platform action bindings
      DevConfig                 dev-only flags (gates the Theme Editor)

    Themes
      DefaultTheme              baseline + canonical token layout
      CartoonTheme / RusticTheme / SciFiTheme
      ThemeSerializer           theme table <-> Luau module source (Export/Import)

    Components                  (all extend UIComponentBase)
      UIComponentBase           lifecycle, animation library, theme registration
      UIButtonComponent  UICardComponent  UIPanelComponent  UIBadgeComponent
      UIToggleComponent  UISliderComponent  UIColorFieldComponent
      UIProgressBarComponent  UIToastComponent

    Controllers
      UIThemeController         theme/pack registry + live switcher (+ runtime themes)
      UIScreenController        screen registry, modal slot, tutorial highlight targets
      UIInputController         action dispatcher (keyboard + gamepad)

    Screens                     (all extend UIScreenBase; one ScreenGui each)
      UIScreenBase
      ShopScreen  GameHUDScreen  TutorialScreen  ModalScreen  ThemeSelectorScreen
```

## How the theme system works

Every component registers with `UIThemeController` when built. Switching a theme
(or dragging a slider in the editor) calls `ApplyThemeObject`, which re-applies
the theme to **all** live components at once — colors cross-fade because each
component tweens with the theme's `ThemeSwap` easing. That is why the entire UI
re-skins with no per-screen wiring.

- **Themes** control *how it looks* (colors, fonts, radii, motion, effects).
- **Packs** control *how it's arranged* (shop grid vs list, HUD compact vs large).
  They're orthogonal — mix any theme with any pack.

## The Export / Import feature

Open the Theme Editor in-game (🎨 on the nav rail, or press **T**). Edit any
color token or numeric token (radii, spacing, animation time, effect scales) and
the whole UI updates live.

- **Export** serializes the live theme into a complete `SomethingTheme.luau`
  module — byte-compatible with the hand-written themes in `UI/Themes`. It's
  copied to your clipboard (where the runtime allows) and shown in a selectable
  box. **Paste that text** into a new file under `UI/Themes/`, add one line to
  `UIThemeConfig`, and it's a permanent registered theme. You can also paste it
  to a developer verbatim — it's the exact module template, so no manual
  retyping of colors.
- **Import** parses a pasted exported module back into a live theme and applies
  it instantly, so the round-trip is fully closed.

`ThemeSerializer.Serialize` / `.Deserialize` power both directions and are
covered by the round-trip smoke test.

## Controls (demo)

| Key | Action |
| --- | --- |
| B | Toggle shop |
| T | Toggle Theme Editor (dev-gated) |
| H | Toggle HUD |
| E | Advance tutorial |
| Esc | Close topmost panel |

## Extending

- **New theme**: drop a module in `UI/Themes`, add it to `UIThemeConfig.Themes`.
- **New pack**: append to `UIPackConfig.Packs`.
- **New shop item**: add one entry to `ShopConfig.Items` (+ a name in `TextConfig`).
- **New component**: extend `UIComponentBase`, override `_Build` / `_Style`.
- **New screen**: extend `UIScreenBase`, require + register it in `ClientHandler`.
- **Localization**: swap `TextConfig.Strings` for a per-locale lookup; every
  screen already goes through `TextConfig.Resolve`.

## Testing

Headless smoke tests via Rojo + run-in-roblox (returns Studio output to the
terminal). Use Argon for live-sync editing, these for verification.

```bash
tools/run-test.sh tools/smoke-test.lua     # config, themes, serializer round-trip, controllers, components
tools/run-test.sh tools/screens-test.lua   # every screen builds/shows/updates; editor export+import
```

Both currently pass (34 + 8 checks).

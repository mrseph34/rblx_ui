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
      UIPackConfig              6 layout packs (container + entry-layout + money/nav placement)
      EntryLayoutConfig         entry arrangement specs (CardTop/Row/Split/TextFirst/Banner)
      UISoundConfig             sound packs (Clean/Arcade/Muted) mapping events -> sounds
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
      UISoundController         pooled per-event UI sounds; swappable sound packs

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
- **Packs** control *how it's arranged* — the entry focal point, grid vs list,
  and where the currency + nav rail sit. They're orthogonal: any theme × any
  pack, always consistent.

### Shape / style (roundness, Flat / Bubbly / Raised3D)

A theme also carries an optional `Shape` token deciding its *feel* independent of
colour: `RoundnessScale` (how round everything is) and a `Style`:

- **Flat** — plain surfaces (the classic look).
- **Bubbly** — pill-round corners + a springy hover bounce (cartoonish).
- **Raised3D** — an inner bevel (light top / dark bottom) + drop shadow that
  *depresses on press*, for an extruded, physical AAA button feel.

`ThemeShape.Resolve(theme)` fills a Flat default for older themes, so Shape is
safe to omit and every component reads it uniformly. Buttons, cards and panels
all honour roundness + Raised3D bevel/shadow, so a style swap ripples everywhere.
There are **16 themes**: the four colour-led originals plus twelve generated
style variants (Midnight, Paper, Mono, Bubblegum, Candy, Jelly, Emboss, Plastic,
Metal, Gemstone, Toxic, Sunset) spanning all three styles.

## Layout packs & the one-renderer rule

The **twelve packs** (Standard, Image Showcase, Compact/List, Detailed/Text,
Split, Hero Banner, Icon Grid, Square Showcase, Inventory List, Spotlight/Mirror
Split, Roster/Portrait, Menu/Settings) look very different, yet a shop entry is
**always** built by one renderer — `UICardComponent`. A pack points its shop at
an `EntryLayoutConfig` spec (`StandardCard`, `ImageFocal`, `ListRow`, `TextHeavy`,
`SplitLeft`, `HeroBanner`, `IconTile`, `SquareShowcase`, `DetailRow`,
`SplitRight`, `Portrait`, `MenuRow`); the renderer builds the same elements
(image, name, description, price, tag pills, buy button) via shared `_Make*`
helpers and only the *arrangement* changes. That is the consistency guarantee:
variety comes from swapping specs, never from bespoke per-pack card code, so two
entries in a pack are structurally identical and a theme paints them the same.
Optional elements (e.g. tags) still **reserve their slot** so a row with none
doesn't shift the rest.

**Image sizing:** grid/card layouts use a **full-width hero image** at a fixed
height — it fills the card edge-to-edge, so there's never an empty gap beside a
shrunken square. Row and split layouts use a square thumbnail (locked with a
`UIAspectRatioConstraint` so it never stretches on any screen), and a portrait
spec (`imageAspect < 1`) renders a tall image **centred** in a full-width row so
it never hugs one side. All card heights are sized so the Buy button always fits.

Hover/press scale an **inner surface** (a `UIScale` on a child), never the
layout-participating root — so a card pops in place without reflowing its
neighbours or spilling out of its cell/scroll area. The shop scroll frame is
padded on every side so the first/last rows and edge columns are never clipped
and content scrolls cleanly as it grows.

Add a new look = add a spec in `EntryLayoutConfig` + point a pack at it. No
renderer or screen changes.

## HUD, vitals & overhead billboards

The HUD is declarative (`HUDConfig`): each element names a value key, a format
(`Number` / `Time` / `Bar`) and a screen region. The **vitals** — health, mana
and stamina bars — are just `Bar` elements grouped bottom-left. **Any** element
can be relocated: a pack sets `HUD.Regions[id] = region`, or the game calls
`GameHUDScreen:SetElementRegion(id, region)` at runtime (priority: runtime
override → pack region → money region → config default). That's how you "put the
money / skills / health anywhere you want" without touching the HUD code.

Above characters, `UIOverheadController` attaches a themed `BillboardGui`
nameplate + vitals bars to the Head. Bars and rows come from `OverheadConfig`,
and the whole plate moves to a different **location preset** (`Above`, `High`,
`Head`, `Front`, `Feet`) with one `SetLocation(character, preset)` call. It
re-skins live with the theme and works for players, NPCs and mobs alike (the game
feeds values, so it isn't tied to `Humanoid.Health`).

## Talking: NPC dialog, chat bubble, chat bar

Three themed ways to show speech, all with a utf8-safe typewriter reveal:

- **`NPCDialogScreen`** — a bottom-anchored panel with a portrait, speaker name
  and choice buttons on the final line. For scripted conversations
  (`NPCDialogConfig` sequences).
- **`UIChatBubbleController`** — an **overhead** `BillboardGui` speech bubble that
  pops above a character's head, types, holds, then fades. For barks / emotes /
  ambient chatter: `chat:Say(character, "Hello!")`.
- **`ChatBarScreen`** — a slim **bottom-of-screen** speech bar (optional speaker)
  that types a line or a queue and auto-advances. For narration / subtitles /
  radio chatter.

## Settings menu

`SettingsScreen` renders `SettingsConfig` into a themed panel: titled sections,
each a scroll of consistent rows built from shared components — a toggle (sliding
knob), a slider (labelled track + value) or a dropdown (`UIDropdownComponent`,
current value + drop list). Values live in a state table and fire `onChange` so a
game can persist them. Adding a setting is a data edit in `SettingsConfig`; the
screen renders whatever it's handed, so every row stays uniform. This is the
text-heavy "options menu" the shop layout can't cover.

## Nav rail (data-driven shortcut buttons)

The floating shortcut buttons (open shop, theme editor, help) are configured in
`NavConfig`: button size (per-button override too), spacing, edge offset, fill
direction, and the button list (icon + action + variant). Sizes and placement are
data, so the buttons resize and reposition like a normal game's "open shop"
button without handler edits. The rail's side/vertical anchor still comes from
the active pack for a per-pack feel.

## Sound packs

`UISoundController` plays abstract events (Hover/Click/Open/Close/Success/Error)
from the active `UISoundConfig` pack. Sounds are Roblox built-ins
(`rbxasset://sounds/*`) so the template makes noise with zero uploaded assets;
packs (`Clean`, `Arcade`, `Muted`) vary sound/pitch/volume. Buttons play
hover/click automatically via the component base; screens play success/error.

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
covered by the round-trip smoke test. (The source viewer is a scrolling box, so
long/wide modules are always fully reachable instead of running off-screen.)

### Export as Script (hand off a whole part)

Beyond the theme, the **📦 Script** button (`PackExporter`) exports a
`.luau` module for the whole pack or any single part — `full`, `shop`, `hud`,
`overheads`, `npc`, `tutorial`, `nav`, `notify`, `settings`, `chat`. Each export:

- returns one `SPEC` table with every resolved theme token, pack/layout choice,
  config value and string that part uses (the **design**, not the renderer code);
- is topped with a **"GET THE REAL CODE" header** pointing at this repo
  (`src/Client/UI`) so a receiving AI reads the actual source for an exact copy,
  plus an **AI build brief** with the architecture rules for rebuilding from the
  SPEC alone.

So you can paste one file into a fresh AI chat (or hand it to a developer): with
the repo it makes an exact copy, and even without it a faithful rebuild from the
SPEC. All ten parts are covered by the export smoke test (each one compiles).

> Note: the in-game export ships the **design SPEC**, not the ~3700 lines of
> renderer code (a running game can't read module source). For the real code,
> point the other AI at this repo — that's what the header does.

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

# Driving & screenshotting the UI via the Studio MCP

How Claude visually tests every theme / pack / screen without you clicking
through them. Requires the `Roblox_Studio` MCP connected (see `STUDIO_MCP.md`)
and Studio open on the **UI TEMPLATES** place.

## The debug seam

`ClientHandler` installs a Studio-only seam (guarded by `RunService:IsStudio()`,
never in a live game): a `ReplicatedStorage/UIDebug` folder of BindableFunctions.
BindableFunctions are used because `_G` is **not** shared between the MCP's
injected `execute_luau` code and the game's own scripts — the DataModel is the
only reliable bridge.

Available (invoke from a `Client` datamodel):

| Call | Effect |
| --- | --- |
| `UIDebug.SetTheme:Invoke("Cartoon")` | live theme swap |
| `UIDebug.ApplyPack:Invoke("Split")` | layout pack: re-render shop, rebuild HUD + nav |
| `UIDebug.SetSoundPack:Invoke("Arcade")` | swap the UI sound pack |
| `UIDebug.ShowScreen:Invoke("shop")` | show a screen (shop seeds balances) |
| `UIDebug.HideScreen:Invoke("tutorial")` | hide a screen |
| `UIDebug.SelectCategory:Invoke("cosmetics")` | switch shop category |

## The loop

1. Verify target: `list_roblox_studios` → `set_active_studio` the **UI TEMPLATES**
   id. Multiple Studios may be open — never assume.
2. Confirm Argon synced source edits before testing:
   `execute_luau(Edit)` reading `<script>.Source` for a marker string.
   Source edits reach Studio via Argon; **data/config changes only take effect
   on a play restart** (the module is cached in the running VM).
3. `start_stop_play(is_start=true)`, then `execute_luau(Client)` with
   `task.wait(2.5)` so the client boots before you poke `UIDebug`.
4. Drive: `UIDebug.HideScreen("tutorial")`, `ApplyPack(...)`, `ShowScreen("shop")`.
5. `screen_capture` to look. If it returns a bare scene, the char just
   respawned mid-capture — capture again.
6. Read the console with `get_console_output` after boot to catch errors.

## Gotchas learned

- **Capture resolution ≠ game resolution.** The capture image is ~1545px wide
  but the game viewport is ~1236px. Do **not** click by screenshot pixels —
  compute a real position from an instance's `AbsolutePosition + AbsoluteSize/2`
  and click that, or click by `instance_path`.
- **Reserved keys.** `Escape` (and other CoreGUI keys) can't be sent via
  `user_keyboard_input`. Drive those flows through `UIDebug` instead.
- **Measure, don't eyeball.** Slice bugs are easier to prove by reading
  `AbsoluteSize` / `AbsoluteContentSize` / `AbsoluteCanvasSize` via
  `execute_luau` than by squinting at a screenshot (that's how the clipped Buy
  button and the missing RGB row were pinned exactly).

## Example: screenshot all six packs

```lua
local dbg = game:GetService("ReplicatedStorage").UIDebug
dbg.HideScreen:Invoke("tutorial")
for _, packId in { "Standard","ImageShowcase","Compact","Detailed","Split","Hero" } do
    dbg.ApplyPack:Invoke(packId)
    dbg.ShowScreen:Invoke("shop")
    task.wait(0.4)
    -- (screen_capture between iterations from the MCP side)
end
```

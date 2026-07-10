# Connecting Claude Code to Roblox Studio (MCP) — cheat sheet

Lets Claude Code drive a playtest, read the console, and simulate clicks/keys
in Studio. Console output + input only — no screenshots.

## One-time setup (do once, ever)

Studio: Assistant widget → "…" menu → **Enable Studio as MCP server** (leave on).

Terminal, run once (user scope = works in every project/game):

```
claude mcp add --scope user --transport stdio Roblox_Studio -- cmd.exe /c "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat"
```

Verify: `claude mcp list`  →  should list `Roblox_Studio`.

## Every session (the routine)

1. Open **Studio** with the place loaded (server only runs while Studio is open).
2. Studio's MCP panel should say **"1 client connected"** once Claude Code attaches.
3. In Claude Code, run `/mcp` — confirm `Roblox_Studio` + its tools appear.
4. Paste the prompt below to me.

## Drop-in prompt (paste this to Claude)

> Studio is open with the rblx_ui place and the Roblox_Studio MCP is connected.
> Use it to playtest: start play, open the Theme Editor (press T), click through
> the shop, read the console output, and report any errors or broken flows. Fix
> what you find, re-run the playtest to confirm, and tell me what changed.

## If it won't connect

- Studio not open / place not loaded → open it first.
- `claude mcp list` doesn't show it → re-run the add command; restart Claude Code.
- Panel still "No clients connected" → restart Claude Code so it re-reads MCP config.
- Enable the first-party tools in Studio's Assistant settings (slider icon):
  start_stop_play, get_console_output, user_mouse_input, user_keyboard_input,
  character_navigation.

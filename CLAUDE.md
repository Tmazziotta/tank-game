# Tank Arena — project rules

Roblox tank arena game with destructible maps. Rojo project: `src/` syncs into Studio via `rojo serve`.

## Rules
- All game logic lives in `src/` as `.luau` files. Never write scripts directly in Studio.
- Server-authoritative: the server decides damage, hits, and destruction. Never trust the client.
- Use `--!strict` and typed Luau. Small modules with single responsibilities.
- Tunable values (speeds, damage, cooldowns, radii) live in `src/shared/Config.luau`.
- After any change, run `scripts/typecheck.sh` (luau-lsp strict analysis; must report no errors), then playtest via the Studio MCP and check console output for errors.

## Layout
- `src/shared` → `ReplicatedStorage.Shared` (Config, shared types, remotes)
- `src/server` → `ServerScriptService.Server` (`init.server.luau` bootstraps server modules)
- `src/client` → `StarterPlayer.StarterPlayerScripts.Client` (`init.client.luau` bootstraps client modules)

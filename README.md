# Tank Arena

Roblox tank arena game (see `DESIGN.md`). Code lives in `src/` and syncs into Studio with [Rojo](https://rojo.space) 7.7.

## Places

One experience, two places:

| Place | Place ID | Project file | Contains |
|---|---|---|---|
| **Garage** (start place, lobby) | 134500042163643 | `garage.project.json` | shared + core + garage code, no arena |
| **Match** (arena) | 117097211658942 | `match.project.json` | shared + core + match code, arena workspace |

`default.project.json` is the **dev** project: everything in one place. Studio uses it, and so does `scripts/typecheck.sh`.

## Developing (dev mode)

```bash
rojo serve            # serves default.project.json
```

Open the Garage place in Studio and connect the Rojo plugin (accept the patch). In Studio, `Config.Places.DevMode` is on, so one server runs both halves: PLAY moves you from the desk into the arena, and after the match you come back to the desk. No teleports happen.

Rojo only picks up changes to `*.project.json` or `remotes/Remotes.model.json` structure after you restart `rojo serve` and reconnect the plugin.

Check after every change:

```bash
scripts/typecheck.sh
```

## Publishing

Build each place from its own project file and publish it over the matching place:

```bash
rojo build garage.project.json -o build/Garage.rbxl
rojo build match.project.json -o build/Match.rbxl
```

For each file: open it in Studio, choose **File → Publish to Roblox As…**, pick this experience, then pick the place to overwrite (Garage or Match).

Game settings (one-time, per place, under Game Settings → Places):
- Garage: Max Players as you like (it's a lobby, e.g. 20).
- Match: **Max Players 8** (4v4).

Note: a teleport inside a Studio playtest loads the *published* destination place, not your synced code. Publish both places before testing teleports outside dev mode.

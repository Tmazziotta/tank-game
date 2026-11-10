# TankGame — Design Doc

> Working title. Living document: update it when decisions change. Claude Code reads this before every milestone.

## Pitch
Short-session tank brawler on Roblox. Chunky toy-style tanks fight in small arenas where **almost everything can be blown apart**. Cover is temporary, so players keep moving, angle their armor, and blast their own flanking routes.

## Pillars
1. **Destruction is tactics, not decoration.** Breaking a wall should open a sightline or a flank.
2. **Easy to drive, deep to master.** WASD + mouse in 10 seconds; armor angling and positioning reward skill.
3. **Rounds are short and every life counts.** 3v3 elimination, 2-minute rounds, best of 5. Dying hurts, but the next round is seconds away.
4. **Fair.** Paid items are sidegrades or cosmetics. Never pay-to-win.

## Core loop
Fight a best-of-5 match → earn coins/XP → unlock or upgrade tanks (or counter-pick between rounds) → queue the next match.

## Game rules
- **Mode (launch):** 3v3 team elimination, best of 5 rounds (first to 3; if draws leave no one at 3 after 5 rounds, most round wins takes it, else a draw). 6-player servers; bots fill empty slots. Replaces the original FFA plan.
- **Round:** pre-round countdown (garage open, tanks frozen), then up to 2:00. A team wins the round by wiping out the other. At the time cap the team with the higher **team health %** wins (remaining HP / max HP summed over the team, dead tanks count 0); an exact tie or a mutual wipe is a draw.
- **Fairness:** map rebuilt every round; teams swap sides each round; one map per match, rotating between matches. Friendly fire off.
- **Damage:** Server-authoritative. Front armor > sides > rear. Steep impact angles reduce damage; past ~70° the shell ricochets.
- **Death:** Explosion, wreck lingers ~5s. No respawn until the next round; you spectate a living teammate.
- **Map reset:** Full rebuild before each round.

## Destruction rules
- **Breakable cover:** Pre-fractured buildings and walls; shells knock out chunks in a blast radius.
- **Crush props:** Fences, crates, small trees; tanks plow through them.
- **Hard cover:** Terrain and key landmarks never break. Every map keeps a skeleton of permanent cover.
- **Performance:** Loose debris is cleaned up after ~8s. Destruction must hold up with 8 players on mobile.

## Tank roster (original designs, toy style)
| Class | Role | Trade-off |
|---|---|---|
| Light | Fast flanker, spotter | Paper armor, low damage |
| Medium | All-rounder | Jack of all trades |
| Heavy | Frontline brawler | Slow, big target |
| Artillery-lite (later) | Lobs shells over cover | Weak up close |

Each class gets 2–3 tanks with upgrade tiers (gun, armor, engine).

## Progression
- **Coins** earned from kills, round wins, match wins/participation, and playtime. Spent on tank unlocks and upgrades.
- **XP / level** gates tiers.
- Data saved with ProfileStore (session locking, autosave).

## Monetization (designed in, not bolted on)
- Premium tanks: sidegrades with unique feel, not stronger stats.
- Cosmetics: camo, decals, turret toppers, explosion effects.
- Game passes: 2x coins, extra loadout slot.
- Dev products: coin packs, XP boosts.
- Private servers.

## Platform targets
- Mobile first-class: touch controls (virtual stick + tap-to-fire + drag-to-aim).
- Keep part counts and physics budgets low; test on a low-end phone profile.

## Milestones
| # | Goal | Done when |
|---|---|---|
| M1 ✅ | Drivable tank, shooting, destructible buildings | Shooting a wall feels good |
| M2 ✅ | Combat: HP, armor angling, death/respawn, FFA round loop | 2-player test has real fights |
| M3 ✅ | Tank roster: 3 classes, class select at spawn | Each class feels distinct |
| M4 ✅ | Progression: coins, XP, unlocks, upgrades, ProfileStore saves | Progress survives rejoin |
| M5 | Maps: 2–3 arenas with crush props and hard-cover skeletons, team-side spawns | Each map plays differently |
| M5b | 3v3 best-of-5 elimination mode (teams, spectate, health tiebreak, bot fill) | A full match with bots plays out start to finish |
| M6 | Polish: UI/HUD, audio, VFX, mobile controls, performance pass | Feels good on phone and PC |
| M7 | Monetization, lobby/menus, analytics events | First purchase flow works end to end |
| M8 | Launch: icon, thumbnails, trailer GIF, maturity questionnaire, publish, friends playtest | Live and playable by the public |
| Post | More modes (e.g. FFA warm-up), events, new tanks/maps, retention tuning | Driven by analytics |

## Out of scope (for now)
- Realistic/historical tank models or any branding from existing tank games
- Ranked matchmaking, clans, trading
- Voxel-level destruction or runtime mesh slicing

## Technical principles
- All logic in `src/` (Rojo). Nothing scripted directly in Studio.
- Server-authoritative; validate every client request.
- Typed Luau (`--!strict`), small single-purpose modules.
- Tunables live in `src/shared/Config.luau`.
- Playtest via Studio MCP after every change; commit after each working piece.

## Success metrics (post-launch)
- Day-1 retention ≥ 20%
- Average session ≥ 10 minutes
- Payer conversion ≥ 1%

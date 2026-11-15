# TankGame — Design Doc

> Working title. Living document: update it when decisions change. Claude Code reads this before every milestone.

## Pitch
Arcade tank brawler set in a giant kid's toy world. Toy tanks from rival toy lines battle across toy-room arenas where **almost everything can be blown apart**. Climb your toy line's tech tree, unlock mods that change how your tank plays, and dress it up with ridiculous hats.

## Pillars
1. **Destruction is tactics, not decoration.** Breaking a wall opens a sightline or a flank.
2. **Easy to drive, deep to master.** WASD + mouse or touch in 10 seconds; armor angling, positioning and mod builds reward skill.
3. **Rounds are short and every life counts.** 4v4 elimination, rounds of up to 3 minutes, best of 5. Dying hurts, but the next round is seconds away.
4. **Unlocks feel great.** Frequent tier and mod unlocks, each one changing how you play, not just numbers.
5. **Fair fights.** Strict same-tier matchmaking, skill-balanced teams. Paid items are cosmetic or sidegrades, never pay-to-win.
6. **Arcade, not realistic.** Toys, bright colors, silly cosmetics.

## Theme: the Toy Room
- **Garage:** a kid's desk; your tank sits on a cardboard turntable among pencils, blocks and crayon drawings.
- **Maps:** toy-scale arenas in a kid's house, where furniture and clutter are the terrain (see Maps).
- **Neon/arcade looks** live on as rare cosmetics (neon paint, glowing trails), not the main theme.
- All toy lines, names and designs are original. No real toy brands, their trade dress, or existing game assets.

## Core loop
Garage → queue → best-of-5 match → podium + rewards → back to Garage → unlock mods/tanks/cosmetics.

## Modes (launch)
- **4v4 Team Battle** (main mode): elimination, best of 5 (see Game rules). Skill-balanced teams.
- **Free-for-all:** 8 players, 3-min rounds, respawn ~5s with ~3s spawn protection, most kills wins.
- **Practice room:** test-drive any tank, including locked ones.
- Ranked (visible rating) comes post-launch when the player base supports it.

## Game rules (4v4 Team Battle)
- **Match:** 4v4 team elimination, best of 5 rounds (first to 3; if draws leave no one at 3 after 5 rounds, most round wins takes it, else a draw). 8-player servers; bots fill empty slots.
- **Round:** pre-round countdown (tanks frozen), then up to 3:00. A team wins the round by wiping out the other. At the time cap the team with the higher **team health %** wins (remaining HP / max HP summed over the team, dead tanks count 0); an exact tie or a mutual wipe is a draw.
- **Counter-pick:** during the countdown you may swap to another tank in your loadout of the tier you queued at.
- **Fairness:** map rebuilt every round; teams swap sides each round; one map per match, rotating between matches. Friendly fire off.
- **Shooting:** shells are server-simulated projectiles with travel time and a little drop; lead moving targets at range. **Shift** (or the scope button) toggles a fixed 4x scope for long shots.
- **Damage:** server-authoritative. Front armor > sides > rear. Steep impact angles reduce damage; past ~70° the shell ricochets.
- **Death:** explosion, wreck lingers ~5s. No respawn until the next round; you spectate a living teammate.
- **Map reset:** full rebuild before each round.

## Matchmaking
- **Strict same tier:** tier 1 never plays tier 2.
- **Hidden skill rating** per player, used to balance teams within a tier.
- **Bots fill empty slots** after ~20s so queues never stall; bot difficulty scales with the lobby's skill.
- **Parties** play at the leader's tier; lower-tier members get a loaner tank for that match.
- Architecture: Garage/lobby place + match servers via reserved servers and a MemoryStore queue. A single-place dev mode (garage and match in one server) is required, since teleports don't run in Studio.

## Toy lines (our "nations")
Launch with 3 lines; more as content updates (Tin Toys, Army Men, Timber Tracks).

| Line | Look | Playstyle | Signature |
|---|---|---|---|
| **Brick Co.** | Snap-together block tanks (original look, no stud-brick trade dress) | Armor, slow | Armor visibly chips; bricks fly off when hit |
| **Plush Patrol** | Stitched stuffed animals, button eyes | Speed, fragile | Squish: bounces off walls, hops small obstacles |
| **Foam Force** | Dart blasters, foam rounds (original colors) | Rapid fire, low per-shot | Clip-based fire, great vs cover |

### Tree shape (per line)
```
Tier 1:   Light
            ├──────────────┬──────────────┐
Tier 2:   Light          Medium         Heavy
            │              │              │
Tier 3:   Light          Medium         Heavy
```
- **Tier 1:** 1 starter, always a **light**.
- **Tier 2:** light, medium and heavy, all unlocked from the tier 1 light.
- **Tier 3:** light, medium and heavy, each unlocked from the same class at tier 2 (light → light, medium → medium, heavy → heavy).
- Long-term target: **7–8 tiers** per line, continuing the three class lanes.
- Each new tier: modest base-stat bump **plus** a new signature mechanic.
- **A new tier's tank arrives stock, but is better than the previous tier fully modded.**

### Mod trees (per tank)
- Each tank has its own mini tree of ~4 rows, unlocked in order with that tank's XP.
- Each row is **pick 1 of 2** mods; once both are unlocked, swap freely in the Toolbox.
- **Mods change how the tank plays, not just percentages.** Examples:
  - Brick Co.: shed bricks stack into a wall behind you · ram plate breaks buildings on contact
  - Plush Patrol: double-hop · squeaky decoy plush that draws fire
  - Foam Force: sticky darts that slow tanks · a "mega dart" as the last shot in each clip
- Completing a tank's tree (elite) unlocks the tank(s) it leads to in the next tier.
- Replaces the old gun/armor/engine upgrade tracks.

### Pacing (tune from data)
- ~30–45 minutes of play per tier for early tiers; can stretch at higher tiers.
- Other lines' tier-1 starters unlock at **player level 3** (~30 min) for a small coin price.

## Tutorial (first join, ~3 min)
1. Wake up on the desk in a tiny tank: drive, aim, shoot.
2. Blast through a block wall: destruction opens paths.
3. **Pick your line:** 20-second test drive of each starter, then choose one (free).
4. Short match vs bots, then into the Garage with a reward popup.

## Garage tabs
1. **Garage (home):** tank on the turntable (drag to spin, idle animations), PLAY + mode pick, level/XP/coins, 3 daily quests, "NEW" dots, and the **loadout bar**: 3 slots of owned tanks you flip between in the garage and take into the queue (like a tank carousel). The game pass adds a 4th slot.
2. **Toy Shelf (tech tree):** one shelf per toy line, tanks as boxed toys by tier; price, requirements, stats, 3D preview, box-opening unlock animation; premium tanks on a glowing shelf.
3. **Toolbox (mods):** the selected tank's mod tree; pick 1 of 2 per row; visible model changes.
4. **Dress Up (customize):** Topper (hats), Paint, Pattern, Decal, Treads, Trail, Kill Effect, Horn, Victory Emote; live preview; randomize; saved outfits. **Cosmetics never change hitboxes or stats.**
5. **Claw Machine (shop):** daily rotating items, featured bundle, coin and Robux prices; the claw spends coins on a random cosmetic (see Monetization for the odds rule).

## Showing off cosmetics
- End-of-match **podium**: top 3 tanks do their victory emotes.
- Kill feed shows the killer's tank; trails and kill effects visible in combat.

## Maps
- **Large and route-based** (~500x500 studs): every map has three routes between the spawns, separated by hard-cover dividers with gaps to cross between them.
  - A fast, open flank with long sightlines (scope country).
  - A close-quarters route through destructible buildings or walls (blast new angles).
  - A high-ground route: a plateau or hill with ramps that overlooks the others.
- **Symmetric:** each map is mirrored across the centerline, and teams also swap sides each round.
- **Slopes:** ramps are at most 10 degrees (tanks stall past ~15). Each ramp spans its plateau's whole side, with corner fills, so there are no inside corners to get stuck in.
- **Ground surfaces** change how tanks drive (speed, acceleration, grip, turning): fast, slightly slow, half speed, slow, and slippery/drifting surfaces, plus shallow wading. Each map has its own mix, so route choice is also a speed choice.
- **Hazards:**
  - **Deep water:** driving in sinks the tank (destroyed; the last attacker gets the kill). Crossed by bridges, shallows or going around, which creates chokepoints.
  - **Minefields:** marked zones of trap hazards. A trap does heavy damage to any team; shells and explosions set them off, so you can shoot a path through (and get credit for enemies caught in it). Traps only chain to very close neighbors, so one never clears a whole field.
- **Hard terrain:** gentle drivable hills (hull-down spots) and a backdrop outside the boundary. Never breaks.
- **Launch maps:** Town, Dockyard and Orchard, already built with real routes, surfaces and hazards, get **converted to the toy-room theme** (own milestone). Layouts and gameplay stay; looks, props and names change. Starting ideas, decided during the conversion:

| Current | Toy-room direction (ideas) |
|---|---|
| Town | Toy town play mat on a rug: block buildings, a spilled-water "river", a ruler bridge |
| Dockyard | Bathroom/bathtub harbor: toy boats, shampoo-bottle containers, soap-slick floor |
| Orchard | Backyard sandbox and garden: plastic fruit, flower pots, a paddling pool pond |
| Surfaces | Wood floor (fast), rug (slight slow), play-dough/slime (mud), sand, spilled juice/soap (slide) |
| Mines | Mousetraps / snap-trap toys |

- **New map:** **The Bedroom** — under the bed, around block towers, through a breakable cardboard castle.
- **Later:** a winter map built around ice (a frozen-over window ledge or freezer).

## Destruction rules
- **Breakable cover:** pre-fractured buildings and walls; shells knock out chunks in a blast radius.
- **Crush props:** tanks plow through small toys and clutter.
- **Hard cover:** key landmarks and terrain never break; every map keeps a permanent skeleton.
- **Performance:** debris cleaned up after ~8s; must hold up with 8 players on mobile.

## Progression & data
- **Coins:** kills, round and match wins, playtime, quests. Spent on tanks, mods, cosmetics.
- **Tank XP:** per tank; unlocks mod rows and the next tier.
- **Player XP / level:** account progression, gates other lines' starters.
- Saved with ProfileStore (session locking, autosave).
- **Data reset:** the toy-lines milestone switches to a new store; existing saves (classes + upgrade tracks) are not migrated.

## Monetization
- Cosmetics (main revenue): toppers, paints, trails, kill effects, emotes, bundles.
- Premium tanks: sidegrades with unique feel, never stronger than tier peers.
- Game passes: 2x coins, extra loadout slot.
- Dev products: coin packs, XP boosts.
- **Claw Machine and Roblox's paid random items policy:** coins can be bought with Robux, so the claw counts as a paid random item. Before every spin it shows a list of every item it can give and its odds, and it is disabled where `PolicyService` reports paid random items are restricted.

## Platform targets
- Mobile first-class: virtual stick, tap-to-fire, drag-to-aim (done).
- Low part counts and physics budgets; test on a low-end phone profile.

## Milestones
| # | Goal | Done when |
|---|---|---|
| M1 ✅ | Drivable tank, shooting, destructible buildings | Shooting a wall feels good |
| M2 ✅ | Combat: HP, armor angling, death, round loop | 2-player test has real fights |
| M3 ✅ | Tank roster basics: Light/Medium/Heavy, class select | Classes feel distinct |
| M4 ✅ | Progression: coins, XP, levels, unlocks, ProfileStore saves | Progress survives rejoin |
| M5 ✅ | Maps: Town, Dockyard, Orchard — three routes, surfaces, water, minefields, terrain; shell travel + scope | Each map plays differently |
| M6 ✅ | Team elimination: best of 5, spectate, health tiebreak, bot fill (built as 3v3) | A full match with bots plays out |
| M7 ✅ | Mobile touch controls: joystick, drag-to-aim, fire/scope/garage/spectate buttons | Playable on a phone |
| M8 ✅ | 4v4: team size 4, 8-player servers, 4 spawns per side on every map | A full 4v4 match with bots plays out |
| M9 | Garage lobby place + teleport to match servers, single-place dev mode | Join → garage → play → back to garage |
| M10 | Toy lines: 3 lines × 3 tiers, tree shape above, per-tank mod trees, loadout bar, data reset | Each line plays differently; unlocks work |
| M11 | Toy-room conversion of Town, Dockyard, Orchard | Each map reads as a toy room and still plays the same |
| M12 | Tutorial + starter line pick | New player reaches first match in ~3 min |
| M13 | Matchmaking: tier queues, hidden skill rating, bots, parties, FFA + practice room | Fair 4v4 with bots filling gaps |
| M14 | The Bedroom map | Map plays well in 4v4 |
| M15 | Polish: HUD, audio, VFX, performance (mobile controls done in M7) | Feels good on phone and PC |
| M16 | Dress Up + Claw Machine (odds list) + podium, monetization | First purchase flow works end to end |
| M17 | Launch: icon, thumbnails, trailer GIF, questionnaire, publish, playtest | Live and playable |
| Post | More tiers, more toy lines, ranked, events, maps, artillery-style tanks | Driven by analytics |

## Out of scope (for now)
- Realistic/historical tanks or branding from existing tank games or real toy brands
- Visible ranked ladder at launch, clans, trading
- Voxel-level destruction or runtime mesh slicing

## Technical principles
- All logic in `src/` (Rojo). Nothing scripted directly in Studio.
- Server-authoritative; validate every client request.
- Typed Luau (`--!strict`), small single-purpose modules.
- Tunables in `src/shared/Config.luau`.
- Playtest via Studio MCP after every change; commit after each working piece.

## Success metrics (post-launch)
- Day-1 retention ≥ 20%
- Average session ≥ 10 minutes
- Median queue time ≤ 20s (bot fill guarantees this; also track the share of humans per match)
- Payer conversion ≥ 1%

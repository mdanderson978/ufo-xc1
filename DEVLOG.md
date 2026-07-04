# UFO: XC1 — Development log

Newest entries first. See [ROADMAP.md](ROADMAP.md) for where this is all headed.

## 2026-07-04 — Phase 2 active-soldier deployment gating

The debug Battlescape now respects campaign soldier availability when launching
a mission. Since debug battles can now mark soldiers wounded or dead, repeat
missions should not redeploy unavailable personnel.

### Step 1: deployable soldier filter
- Debug battles now draw their squad from active campaign soldiers only.
- Soldiers marked `dead`, `wounded`, or carrying positive wound days are skipped.
- The debug loadout assignment still happens on duplicated soldier records, so
  campaign soldier data is not mutated by mission setup.

### Step 2: empty-squad handling
- If no active soldiers are available, the debug view does not create a battle
  state.
- Input handlers now guard against the no-battle state and the status line
  explains that no active soldiers are available.

### Step 3: tests
- Added scene-level smoke coverage for skipping unavailable soldiers and for
  the no-deployable-soldiers state.

### Commit note
- Intended commit boundary: `Phase 2: gate debug deployments by soldier status`.

## 2026-07-04 — Phase 2 debug battle campaign handoff

The debug Battlescape now closes the tactical-to-campaign loop in the running
app. Finished debug battles apply their result to `GameState`, emit the existing
`battle_finished` signal, and guard against duplicate result application.

### Step 1: live campaign source
- The debug Battlescape now starts battles from `GameState.campaign` when a
  campaign is active.
- If no campaign exists, the debug view creates one so the skirmish entry point
  still works in isolation.

### Step 2: single finish path
- Added a guarded `_finish_battle()` path that applies `BattleState.battle_result()`
  through `GameState.apply_battle_result()`.
- The same path emits `EventBus.battle_finished`.
- Move, attack, and alien-turn completion now all use this finish path.

### Step 3: tests
- Added a scene-level smoke test that forces a debug battle win, verifies
  campaign score/soldier mission application, verifies the event emission, and
  confirms repeat finish calls do not double-apply rewards.

### Commit note
- Intended commit boundary: `Phase 2: wire debug battle campaign handoff`.

## 2026-07-04 — Phase 2 campaign rewards

Battle rewards now land in campaign state instead of stopping at the tactical
result dictionary. The same `apply_battle_result()` path that updates soldiers
now also updates monthly score and base stores.

### Step 1: score application
- `CampaignFactory.apply_battle_result()` now adds `score_xcom` to
  `campaign.score.month_xcom`.
- The function still works on a deep copy so callers keep immutable input
  semantics.

### Step 2: recovered item stores
- Recovered items from `battle_result.recovered_items` now merge into the
  selected base's stores.
- Existing item quantities increment and newly recovered item ids are inserted.

### Step 3: tests
- Added coverage for monthly score updates, recovered new item insertion,
  existing store accumulation, no input mutation, and the `GameState` wrapper.

### Commit note
- Intended commit boundary: `Phase 2: apply campaign rewards`.

## 2026-07-04 — Phase 2 post-mission wounds

Battle results now carry enough survivor health information for the campaign
layer to mark soldiers wounded after a mission. This closes another piece of
the tactical-to-campaign handoff without adding Geoscape time passage yet.

### Step 1: wound result output
- `BattleState.battle_result()` now includes `xcom_wounds`.
- Surviving XCOM units with missing health receive deterministic wound days
  based on missing health.
- Dead units remain losses and do not receive wound entries.

### Step 2: campaign application
- `CampaignFactory.apply_battle_result()` now applies wound days to surviving
  soldiers.
- Wounded survivors are marked `status = "wounded"` and healthy survivors are
  restored to `status = "active"` with zero wound days.
- Dead soldiers still take precedence over any wound data.

### Step 3: tests
- Added coverage for wound result output, wounded survivor campaign state,
  healthy survivor wound clearing, KIA precedence, and the `GameState` wrapper.

### Commit note
- Intended commit boundary: `Phase 2: apply post-mission wounds`.

## 2026-07-04 — Phase 2 soldier XP and rank application

Mission results can now feed soldier progression back into campaign save data.
This keeps the loop plain-data and deterministic: Battlescape reports mission
kills and XP awards, then the campaign layer applies them to base soldiers.

### Step 1: mission-only kill accounting
- `BattleUnit.from_soldier()` now starts `kills_current` at zero instead of
  copying career kills into mission state.
- This prevents veteran soldiers from double-counting prior kills when a battle
  result is applied.

### Step 2: battle XP awards
- `BattleState.battle_result()` now includes `xcom_xp`.
- XCOM soldiers earn survival XP and per-kill XP from the mission result.

### Step 3: campaign application
- New campaign soldiers now carry `xp` and `rank` fields.
- `CampaignFactory.apply_battle_result()` updates participating soldiers'
  missions, career kills, XP, rank, and KIA status without mutating the input
  campaign dictionary.
- `GameState.apply_battle_result()` exposes the same flow for future screens.

### Step 4: tests
- Added coverage for mission-only kill accounting, XP result output, campaign
  soldier updates, KIA handling, rank promotion, and the `GameState` wrapper.

### Commit note
- Intended commit boundary: `Phase 2: apply soldier XP and ranks`.

## 2026-07-04 — Phase 2 fog-of-war memory

The tactical model now distinguishes current line of sight from tiles a side has
already discovered. This gives the debug Battlescape the classic three-state
fog model: unseen, remembered, and currently visible.

### Step 1: discovered tile cache
- `BattleState` now tracks `discovered_tiles` for XCOM and aliens alongside
  current `visible_tiles`.
- Battle start clears current and discovered visibility, then seeds discovery
  from the initial visibility refresh.

### Step 2: visibility refresh integration
- Every visibility refresh now merges current visible tiles into discovered
  memory for each team.
- Added `has_seen()` and `discovered_tile_list()` for presentation and future AI
  consumers.

### Step 3: serialization and debug rendering
- Battle serialization now includes discovered tiles.
- The debug Battlescape renders never-seen tiles as dark unknown space, while
  previously seen but currently hidden tiles keep terrain silhouettes under fog.

### Step 4: tests
- Added deterministic coverage for never-seen blocked LOS, discovery after a
  sightline opens, and remembered tiles after LOS is blocked again.

### Commit note
- Intended commit boundary: `Phase 2: add fog of war memory`.

## 2026-07-04 — Phase 2 morale and panic

The tactical model now has its first morale consequences. Deaths can shake
surviving allies, and badly shaken units can panic at the start of their turn.

### Step 1: unit morale state
- `BattleUnit` now tracks whether it panicked this turn.
- Turn start clears the panic flag before any new panic checks run.

### Step 2: morale loss on death
- When an attack or reaction fire kills a unit, living allies on that unit's
  team lose morale.
- Morale loss scales with bravery and is recorded as structured morale events.

### Step 3: panic checks
- At turn start, living units under 30 morale roll against a bravery-adjusted
  panic chance.
- Panicked units lose all TU for that turn and emit a structured panic event.

### Step 4: result/debug plumbing
- Movement, attack, end-turn, battle serialization, and battle results now
  expose morale events.
- The debug Battlescape status line summarizes morale losses and panic events.

### Step 5: tests
- Added deterministic coverage for allied morale loss after a death and panic
  at turn start.

### Commit note
- Intended commit boundary: `Phase 2: add morale and panic`.

## 2026-07-04 — Phase 2 mission result and recovery

Battles now produce a structured result that the campaign layer can consume
later. This closes the first tactical loop at the data level: kill aliens,
win the battle, recover corpses and UFO loot.

### Step 1: unit kill/recovery metadata
- `BattleUnit` now tracks current mission kills.
- Alien units carry `corpse_item` and `score_kill` from `data/aliens.json`.

### Step 2: deterministic UFO recovery loot
- `BattleState.from_crash_site()` now stores the UFO id and rolls recovery
  loot from `data/ufos.json` using the mission RNG.
- The rolled loot remains on the battle state until a battle result is built.

### Step 3: battle result
- Added `BattleState.battle_result()`.
- Results include outcome, turn number, UFO id, XCOM survivors/losses, aliens
  killed/survived, per-side kill counts, XCOM score from killed aliens, and
  recovered items.
- XCOM wins recover UFO loot plus corpses from killed aliens. Alien wins
  recover nothing.

### Step 4: debug result summary
- The debug Battlescape status line now displays battle result summaries when
  a move, attack, or alien turn ends the battle.

### Step 5: tests
- Added coverage for kill counting, UFO loot recovery, alien corpse recovery,
  XCOM scoring, and no recovery after alien victory.

### Commit note
- Intended commit boundary: `Phase 2: add mission results and recovery`.

## 2026-07-04 — Phase 2 reaction fire

Movement now risks enemy fire. This is the first deterministic, headless
reaction-fire implementation and is intentionally scoped to movement triggers.

### Step 1: movement-triggered reactions
- `BattleState.move_unit()` now resolves movement step by step.
- After each step, visibility refreshes and opposing living units may react if
  they can see the mover, have a snap-capable weapon, and have enough TU.
- Reaction chance is based on reactor reactions versus mover reactions, capped
  between 5% and 95%.
- Reaction shots spend TU through `BattleRules.attack()` and can damage or kill
  the mover. If the mover dies, the remaining path is cancelled.

### Step 2: action results
- Movement results now include a `reactions` array containing reaction checks
  and fired reaction shots.
- The debug Battlescape status line summarizes reaction-fire shots and hits
  after player movement.

### Step 3: tests
- Added deterministic coverage for reaction fire triggering, TU spending, and
  reaction fire killing a mover and stopping the path.
- Existing movement tests opt out with `reaction_fire_enabled = false` when
  they are testing movement in isolation.

### Commit note
- Intended commit boundary: `Phase 2: add reaction fire`.

## 2026-07-04 — Phase 2 basic alien AI

The debug Battlescape now has an opposing turn. This is the first simple AI
pass, not the final tactical brain.

### Step 1: headless AI runner
- Added `BattleAI`, a scene-free RefCounted helper that acts through
  `BattleState` instead of bypassing rules.
- Aliens fire snap shots at visible XCOM units when they have line of sight.
- If no XCOM unit is visible, aliens path a limited number of steps toward the
  nearest living XCOM unit.
- Added `BattleState.unit_at()` as a public occupancy query for AI/pathing.

### Step 2: tests
- Added `tests/test_battle_ai.gd`.
- Covered visible-target shooting, unseen-target advance, and no-op behavior
  outside the alien turn.

### Step 3: debug screen wiring
- The debug Battlescape `End Turn` button now advances to the alien side,
  resolves `BattleAI.run_alien_turn()`, then returns control to XCOM if the
  battle is still active.
- The status line summarizes alien attacks, moves, and waits.

### Commit note
- Intended commit boundary: `Phase 2: add basic alien AI`.

## 2026-07-04 — Phase 2 debug Battlescape view

The first playable tactical debug surface is now wired into the main menu. It
is intentionally plain 2D rendering over the headless `BattleState`; the final
presentation can change without rewriting rules.

### Step 1: route and launcher
- Registered `battlescape` in the top-level screen router.
- Wired the main menu `Skirmish (debug)` button to launch a seeded small-scout
  crash-site battle.

### Step 2: debug scene
- Added `src/battlescape/battlescape.tscn` and `battlescape_debug.gd`.
- The view creates a deterministic debug battle from campaign soldiers, assigns
  rifles for the skirmish, and renders the generated 40x40 tactical map as 2D
  tiles.

### Step 3: interaction
- Click a blue XCOM marker to select it.
- Click a reachable visible tile to path/move through `BattleState.move_unit()`.
- Click a visible red alien marker to fire a snap shot through
  `BattleState.attack_unit()`.
- Added debug controls for back, new seed, and end turn.

### Step 4: smoke coverage
- Extended screen smoke tests so registered screens not only instantiate, but
  also enter the scene tree and run `_ready()`.

### Commit note
- Intended commit boundary: `Phase 2: add debug battlescape screen`.

## 2026-07-04 — Phase 2 battle state controller

The Battlescape now has the first mission-level controller on top of the map,
unit, and rules primitives.

### Step 1: mission state owner
- Added `BattleState`, a scene-free RefCounted controller for tactical
  missions.
- It owns the `BattleMap`, unit dictionary/order, active team, turn number,
  deterministic RNG seed, visibility cache, spotted-enemy lists, and battle
  outcome.

### Step 2: crash-site battle setup
- Added `BattleState.from_crash_site()` to build a mission from static data:
  `CrashSiteGenerator`, UFO crew ranges, soldier records, XCOM spawn tiles,
  alien spawn tiles, and item data.
- The setup path starts XCOM on turn 1 and immediately builds visibility.

### Step 3: action API
- Added `move_unit(unit_id, path)`, which enforces active-team ownership,
  living-unit checks, occupied-tile rejection, TU spending through
  `BattleRules`, and visibility refresh after movement.
- Added `attack_unit(attacker_id, target_id, fire_mode)`, which enforces
  active-team and enemy-target checks, then delegates hit resolution to
  `BattleRules`.
- Added `end_turn()`, which detects battle end before handing off, swaps active
  team, increments the turn when control returns to XCOM, and refreshes TU for
  the new active side.

### Step 4: visibility and outcome
- Added side-specific visible-tile caches and spotted-enemy lists using
  `BattleRules.can_see()`.
- Added win/loss outcomes: `active`, `xcom_win`, and `alien_win`.

### Step 5: tests
- Added `tests/test_battle_state.gd` covering crash-site placement, visibility,
  sight-blocked enemies, turn handoff, TU refresh, active-team rejection,
  occupied-tile rejection, movement visibility refresh, and win/loss outcomes.

## 2026-07-04 — Phase 2 tactical rules slice

The Battlescape now has its first headless combat rules, still with no scene
or UI dependency.

### Step 1: tactical unit state
- Added `BattleUnit`, a plain RefCounted model for mission units. It can build
  XCOM units from campaign soldier records and aliens from `data/aliens.json`,
  carrying position, team, stats, armor, loadout, current TU, health, and
  morale.
- Units reset TU at the start of their turn and serialize to JSON-native data.

### Step 2: TU movement
- Added `BattleRules.step_tu_cost`, `move_step`, and `move_path`.
- Movement spends the destination tile's terrain TU cost, rejects blocked
  tiles, rejects non-adjacent steps, and refuses movement when the unit lacks
  enough TU.
- Diagonal movement has its own cost multiplier so `BattleMap.tu_cost` can
  remain a simple tile query.

### Step 3: line of sight
- Added deterministic Bresenham LOS checks over `BattleMap.blocks_sight`.
- Sight-blocking terrain and obstacles now gate attacks in headless rules,
  ready for fog-of-war and reaction-fire systems to build on.

### Step 4: first attack resolver
- Added a seed-driven weapon attack path using existing item data:
  weapon accuracy, TU percentage cost, clip damage, target cover, and armor.
- Attacks spend TU only after validation, require LOS, produce a deterministic
  roll, and apply front-armor-reduced damage.

### Step 5: tests
- Added `tests/test_battle_rules.gd` covering unit initialization, TU movement,
  blocked movement, insufficient TU, LOS blockage/destruction, attack spending,
  deterministic damage, and attack LOS validation.

### Step 6: data validation
- Extended `DataRegistry.validate()` so `data/terrain.json` is now a required
  table.
- Terrain validation now catches missing `kind` fields, destructible terrain
  that transforms into a nonexistent terrain id, and recovery loot pointing at
  nonexistent items.

## 2026-07-04 — Project born: Phases 0–1 complete, Battlescape underway

One day, three phases of groundwork. Everything below runs and is covered by
headless tests (the Phase 0-1 suite was 14 tests, 383 assertions, all green).

### Phase 2 started: Battlescape map model
- `BattleMap` — the tactical grid as pure, scene-free data: terrain queries
  (walkability, TU step costs, sight blocking, cover values) and destructible
  obstacles (UFO hull walls break into see-through breaches; fences and
  hedges can be shot away).
- `CrashSiteGenerator` — deterministic farmland crash sites from a seed:
  wheat-field bands, fence/hedge boundaries with gaps, tree scatter, a
  scorched crash trail with wreckage, and a circular UFO hull (sized by UFO
  class) with door, alien consoles, and crew spawn tiles.
- Tests guarantee: same seed ⇒ identical map; every alien spawn (including
  inside the UFO) is reachable from the Skyranger deployment zone, so no
  mission can generate unwinnable.

### Phase 1: data layer & campaign state
- All game content is JSON in `data/`: 14 items (conventional tier, laser
  tier, alien plasma, materials, corpses), 3 alien types, 9 facilities,
  a 12-node research tree (Laser Weapons → … → Alien Origins), 2 craft,
  3 UFO classes, 16 funding nations, soldier stat ranges + name pools,
  16 terrain tile types.
- `DataRegistry` validates every cross-reference on load (a research project
  requiring a nonexistent item is a startup error, not a mid-game crash).
- `CampaignFactory` builds the deterministic starting state from a seed:
  one base (8 facilities), 8 soldiers with rolled stats, portraits and an
  `appearance_seed` that will drive their 3D model generation, starting
  stores, an Interceptor and a Skyranger, and the funding council.
- Saves are plain JSON in a canonical form (`Jsonish`) — a save/load round
  trip is byte-identical, and tests enforce that.

### Phase 0: toolchain & the character factory
- **Godot 4.7** (Forward+) project skeleton: screen router, autoload
  singletons (`EventBus`, `DataRegistry`, `GameState`, `SaveManager`),
  main menu, GUT test framework running headless.
- **The character factory** — the riskiest bet, proven first:
  `tools/pipeline/generate_soldier.py` drives **Blender 4.5 LTS** headless:
  MPFB2 (MakeHuman) generates a realistic human from a seed (build, age,
  ethnicity), attaches the CMU-compatible skeleton, the Diffeomorphic BVH
  Retargeter maps real **CMU motion-capture** clips onto it, and it exports
  a GLB that Godot imports clean (31 bones, working walk cycle). Every
  soldier and Sectoid rolls off this line; a new seed is a new face.
- **First 12 AI-generated images integrated** (title key art, menu
  background, Sectoid portrait, 6 soldier portraits, 3 tileable albedo
  textures) via `integrate_incoming.py` — WebP conversion + power-of-two
  resize took the batch from 28 MB to 2.1 MB. The prompt queue lives in
  `assets/PROMPTS.md`.
- Repo went public on GitHub under **GPLv3** the same hour it was created.

### Decisions of record
- **Engine**: Godot 4.7, GDScript, Forward+ — text-based scenes/scripts,
  headless CLI testing, clean Windows export. Chosen over Unity/Unreal for
  automation-friendliness and zero licensing friction.
- **Combat**: faithful 1994 Time-Unit system (not the 2012 two-action model).
- **Signature feature**: possession mode — first-person control of any
  soldier, same TU economy, manual aim with accuracy-driven crosshair sway.
- **Art**: realistic high-fidelity; no low-poly. Characters from the Blender
  factory, materials from Poly Haven (CC0), 2D art from the maintainer's AI
  image subscription.
- **Architecture**: rules are scene-free GDScript (headless-testable);
  scenes are thin views; content is JSON, never code.

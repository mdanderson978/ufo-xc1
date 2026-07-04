# UFO: XC1 — Development log

Newest entries first. See [ROADMAP.md](ROADMAP.md) for where this is all headed.

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

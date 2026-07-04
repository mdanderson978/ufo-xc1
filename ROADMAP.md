# UFO: XC1 — Roadmap

Status: **Milestone 1 in progress** (started 2026-07-04).

## Milestone 1 — Playable core loop

The whole campaign loop, real but content-light: one biome, 3 alien types,
~12 research items.

| Phase | Scope | Status |
|-------|-------|--------|
| 0 | Toolchain, project skeleton, character factory (MPFB2 + CMU mocap → GLB), CI-able headless tests | ✅ done |
| 1 | Data layer: items, aliens, facilities, research tree, crafts, UFOs, nations as JSON; campaign state model + save/load | ✅ done |
| 2 | **Battlescape**: TU combat, LOS/fog, reaction fire, alien AI, morale, mocap-animated units, **possession mode** (first-person TU-metered control), mission end/loot/XP | 🔨 in progress — map model, crash-site generator, unit state, TU movement, LOS/fog memory, reaction fire, first attack resolver, battle state/turn controller, debug 2D Battlescape view, basic alien AI, morale/panic, mission result/loot recovery, soldier XP/rank application done |
| 3 | **Geoscape**: 3D globe, time compression, UFO detection, interception, crash sites, monthly funding council | ⬜ |
| 4 | **Basescape**: facility grid, personnel, research allocation, manufacturing, market, soldier equip | ⬜ |
| 5 | Integration: full loop closure, save anywhere, menus/options, Windows export | ⬜ |

## Milestone 2+ (backlog, unordered)

- Multiple bases; base-defence missions
- Terror missions and terror units
- Psionics
- Destructible terrain simulation (M1 only flags destroyed tiles)
- More biomes (desert, urban, polar), night-mission gear
- Flying units / multi-storey maps beyond 2 levels
- Full UFOpaedia
- Difficulty settings
- Audio pass: adaptive music
- Localisation

## Design pillars

1. **Faithful Time-Unit tactics** — the 1994 ruleset feel, not the 2012 one.
2. **Modern presentation** — Godot Forward+ (GI, volumetrics, PBR), realistic
   characters from an automated Blender/MakeHuman/mocap pipeline.
3. **Possession mode** — any soldier, first person, same TU rules.
4. **Data-driven** — content lives in `data/*.json`; adding content ≠ code.
5. **Logic/presentation split** — rules are headless-testable pure GDScript.

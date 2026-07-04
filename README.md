# UFO: XC1

**A modern reimagining of the 1994 classic *UFO: Enemy Unknown* (X-COM: UFO Defense) — high-fidelity 3D graphics, the faithful Time-Unit turn-based combat of the original, and one new trick: possess any of your soldiers and fight in first person.**

> ⚠️ Early development. The project is being built in public — nothing is playable yet. Watch/star if you want to follow along, and see [Contributing](#contributing) if you'd like to get involved.

## What this is

Earth, near future. UFO activity is escalating. You command XC1 — humanity's covert extraterrestrial-combat initiative. Manage your base, fund your war through a council of nervous nations, research recovered alien technology, and lead soldiers who can actually die into turn-based tactical combat.

**Faithful where it counts:**
- **Time Units** — every action costs TUs: moving, turning, kneeling, snap/aimed/auto fire. No two-action streamlining.
- **Reaction fire, morale, fog of war**, per-soldier stats and progression, permadeath.
- **The full strategic layer** — Geoscape with time compression and UFO interception, base construction and maintenance, research trees, manufacturing, monthly funding council reports.

**Modern where it matters:**
- **Godot 4 Forward+ rendering** — PBR materials, global illumination, volumetric fog, modern lighting.
- **Possession mode** — Dungeon Keeper style. During your turn, drop into any soldier in first person. WASD movement drains their TUs; aiming is manual, with crosshair sway driven by that soldier's accuracy stat. A rookie's barrel wanders. A veteran's is steady. Alien reaction fire still applies — possession is a control layer, not a cheat.

## Tech

| Piece | Choice |
|---|---|
| Engine | [Godot 4.7](https://godotengine.org) (GDScript, Forward+) |
| Character pipeline | Blender (headless, scripted) + MPFB2/MakeHuman + CMU mocap |
| Materials/lighting | Poly Haven CC0 PBR + HDRI |
| Game data | JSON in `data/` — fully data-driven content |
| Tests | GUT, run headless in CI |

All rules logic (TU costs, hit chance, LOS, economy) is engine-node-free GDScript, unit-tested headless. Scenes are thin views.

## Running from source

1. Download [Godot 4.7 stable](https://godotengine.org/download) (standard build).
2. Clone this repo, open `project.godot` with Godot.
3. Run the main scene (F5). The `tests/` suite runs via GUT headless — see `tools/run_tests.md` (coming with Phase 0 completion).

## Roadmap

- **Milestone 1 — playable core loop** *(in progress)*: one biome, 3 alien types, ~12 research items, but the whole loop real: detect → intercept → tactical battle (incl. possession mode) → loot → research → manufacture → month-end council report.
- **Milestone 2+**: multiple bases, terror missions, base defence, psionics, more biomes/aliens/tech, destructible terrain simulation.

## Contributing

Interest and contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for setup and ground rules, and [ROADMAP.md](ROADMAP.md) for where the project is headed. Good early ways to help: playtesting builds, game-balance data, CC0 asset curation, and Godot/GDScript review.

## Legal

UFO: XC1 is an original fan reimagining. It contains **no assets, code, or data from the original game**, and is not affiliated with or endorsed by the rights holders of the X-COM franchise. All bundled assets are CC0/CC-BY (see `assets/CREDITS.md`) or original to this project.

Code licensed under the [GNU GPLv3](LICENSE) — UFO: XC1 is and will remain open source, and so must every fork or derivative. Bundled art/audio remain under their own open licenses (CC0/CC-BY, per `assets/CREDITS.md`).

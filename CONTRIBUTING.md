# Contributing to UFO: XC1

Thanks for your interest! The project is very young and core architecture is
still moving fast — **open an issue to say hi or pitch an idea before sending
large PRs.**

## Getting set up

1. Install [Godot 4.7 stable](https://godotengine.org/download) (standard build).
2. Clone the repo and open `project.godot`.
3. Restore gitignored third-party assets: `bash tools/pipeline/fetch_third_party.sh`
   (needs `curl` + `python`; on Windows use Git Bash).
4. Run tests headless:
   `godot --headless --path . -s res://addons/gut/gut_cmdln.gd`

The character pipeline additionally needs Blender 4.5 LTS with the MPFB2
extension and the Diffeomorphic BVH Retargeter addon — only required if you're
regenerating characters (`tools/pipeline/generate_soldier.py`), not for
gameplay work.

## Ground rules

- **License**: all code contributions are GPLv3. Asset contributions must be
  CC0 or CC-BY with attribution recorded in `assets/CREDITS.md`.
- **No original X-COM assets or data.** Ever. This is a clean-room reimagining.
- **Architecture**: game rules live in plain, scene-free GDScript under
  `src/*/systems|map|units` and must have GUT tests. Scenes are thin views.
  Content belongs in `data/*.json`, not code.
- **Tests must pass** before a PR: see the headless command above.
- Match the existing code style (typed GDScript, tabs, snake_case).

## Good first areas

- Playtesting and balance feedback once the skirmish build lands (Phase 2)
- CMU mocap clip curation (finding good clip numbers in the index for
  aim/crouch/hit/death actions)
- Game data: weapon/facility/research stats in `data/`
- UI/UX polish on menus and HUD

See [ROADMAP.md](ROADMAP.md) for where the project is headed.

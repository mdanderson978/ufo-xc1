# Asset credits & licenses

Every third-party asset used by UFO: XC1, its source, and its license.
Fetchable assets live in `assets/third_party/` (gitignored) and are restored
by `tools/pipeline/fetch_third_party.sh`.

## Tools (not shipped in the game)

| Tool | Source | License |
|------|--------|---------|
| Godot 4.7 | godotengine.org | MIT |
| Blender 4.5 LTS | blender.org | GPL |
| MPFB2 2.0.16 (MakeHuman for Blender) | extensions.blender.org/add-ons/mpfb | GPL/AGPL (tool); **generated characters are unencumbered output** |
| BVH Retargeter 4.4.0 (Diffeomorphic) | github.com/Diffeomorphic/retarget_bvh | GPL-2.0+ (tool only) |
| GUT 9.7.0 (test framework) | github.com/bitwes/Gut | MIT |

## Data & assets (shipped or baked into shipped assets)

| Asset | Source | License |
|-------|--------|---------|
| CMU Motion Capture Database (BVH conversion) | mocap.cs.cmu.edu via github.com/una-dinosauria/cmu-mocap | Free for all uses; courtesy credit: "Data obtained from mocap.cs.cmu.edu. Database created with funding from NSF EIA-0196217." |
| Poly Haven HDRIs & PBR textures | polyhaven.com | CC0 |
| Generated soldier/alien models (`assets/characters/*.glb`) | produced by this repo's pipeline (`tools/pipeline/generate_soldier.py`) | Project assets, CC-BY-4.0 |
| AI-generated images (`assets/incoming/`, integrated under `assets/`) | project maintainer's AI image subscription | Project assets, CC-BY-4.0 |

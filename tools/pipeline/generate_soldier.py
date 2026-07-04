"""UFO: XC1 character factory — generate a rigged, animated soldier GLB.

Run:
  blender --background --python tools/pipeline/generate_soldier.py -- \
      --out assets/characters/soldier_test.glb [--seed 42]

Pipeline: MPFB2 human (randomised macros from seed) -> cmu_mb rig with
weights -> CMU BVH clips imported as actions -> GLB export.
"""
import argparse
import importlib
import random
import sys
from pathlib import Path

import bpy

MPFB = "bl_ext.user_default.mpfb"
PROJECT_ROOT = Path(__file__).resolve().parents[2]

# Phase 0 proof clip; the full clip set is curated in Phase 2.
ANIMATIONS = {
    "walk": PROJECT_ROOT / "assets/third_party/mocap/07_01_walk.bvh",
}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--seed", type=int, default=1)
    return parser.parse_args(argv)


def service(name, cls):
    return getattr(importlib.import_module(f"{MPFB}.services.{name}"), cls)


def random_macros(rng):
    """Randomised but soldier-plausible MakeHuman macro settings (0..1)."""
    return {
        "gender": rng.choice([rng.uniform(0.75, 1.0), rng.uniform(0.0, 0.25)]),
        "age": rng.uniform(0.45, 0.65),        # mid 20s to 40s
        "muscle": rng.uniform(0.6, 0.85),
        "weight": rng.uniform(0.45, 0.6),
        "height": rng.uniform(0.5, 0.7),
        "proportions": rng.uniform(0.4, 0.6),
        "race": _random_race(rng),
    }


def _random_race(rng):
    weights = [rng.random() for _ in range(3)]
    total = sum(weights)
    return {
        "asian": weights[0] / total,
        "african": weights[1] / total,
        "caucasian": weights[2] / total,
    }


def main():
    args = parse_args()
    rng = random.Random(args.seed)

    HumanService = service("humanservice", "HumanService")

    # Fresh scene.
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.ops.preferences.addon_enable(module="retarget_bvh")

    print(f"FACTORY: creating human (seed={args.seed})")
    basemesh = HumanService.create_human(
        mask_helpers=True,
        detailed_helpers=False,
        extra_vertex_groups=False,
        feet_on_ground=True,
        macro_detail_dict=random_macros(rng),
    )

    print("FACTORY: adding cmu_mb rig with weights")
    armature = HumanService.add_builtin_rig(basemesh, "cmu_mb")

    actions = []
    for clip_name, bvh_path in ANIMATIONS.items():
        print(f"FACTORY: retargeting clip '{clip_name}' from {bvh_path.name}")
        bpy.ops.object.select_all(action="DESELECT")
        armature.select_set(True)
        bpy.context.view_layer.objects.active = armature
        bpy.ops.mcp.load_and_retarget(filepath=str(bvh_path))
        if armature.animation_data and armature.animation_data.action:
            action = armature.animation_data.action
            action.name = clip_name
            actions.append(action)

    print(f"FACTORY: actions = {[a.name for a in actions]}")
    if len(actions) != len(ANIMATIONS):
        print("FACTORY-FAIL: not all clips retargeted")
        sys.exit(1)

    out_path = (PROJECT_ROOT / args.out).resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)

    # Select mesh + armature for export.
    bpy.ops.object.select_all(action="DESELECT")
    basemesh.select_set(True)
    armature.select_set(True)

    print(f"FACTORY: exporting {out_path}")
    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        use_selection=True,
        export_format="GLB",
        export_animations=True,
        export_skins=True,
        export_yup=True,
        export_apply=False,
    )
    print("FACTORY-OK")


main()

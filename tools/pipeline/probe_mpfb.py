"""Probe: verify MPFB2 can create a rigged human entirely headless.

Run:  blender --background --python tools/pipeline/probe_mpfb.py
"""
import importlib
import sys

import bpy


def find_mpfb_root():
    """MPFB module path differs between legacy addon and 4.2+ extension."""
    for name in ("bl_ext.user_default.mpfb", "mpfb"):
        try:
            importlib.import_module(name)
            return name
        except ImportError:
            continue
    return None


def main():
    root = find_mpfb_root()
    if root is None:
        print("PROBE-FAIL: cannot import mpfb module")
        sys.exit(1)
    print(f"PROBE: mpfb root = {root}")

    human_service = importlib.import_module(f"{root}.services.humanservice")
    HumanService = human_service.HumanService

    basemesh = HumanService.create_human()
    print(f"PROBE: created human mesh '{basemesh.name}' "
          f"verts={len(basemesh.data.vertices)}")

    # List what services exist so we know the API surface for rigging/export.
    import pkgutil
    services_pkg = importlib.import_module(f"{root}.services")
    names = [m.name for m in pkgutil.iter_modules(services_pkg.__path__)]
    print(f"PROBE: services = {sorted(names)}")

    # Inspect HumanService for rig/proxy helpers.
    api = [n for n in dir(HumanService) if not n.startswith("_")]
    print(f"PROBE: HumanService api = {sorted(api)}")

    print("PROBE-OK")


main()

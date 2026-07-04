"""Probe 2: inspect MPFB API signatures for rigging, morphs, animation."""
import importlib
import inspect

ROOT = "bl_ext.user_default.mpfb"


def show(mod_name, cls_name):
    mod = importlib.import_module(f"{ROOT}.services.{mod_name}")
    cls = getattr(mod, cls_name)
    print(f"=== {cls_name} ===")
    for name in dir(cls):
        if name.startswith("_"):
            continue
        member = getattr(cls, name)
        if callable(member):
            try:
                print(f"  {name}{inspect.signature(member)}")
            except (ValueError, TypeError):
                print(f"  {name}(?)")
    print()


show("humanservice", "HumanService")
show("rigservice", "RigService")
show("animationservice", "AnimationService")
show("targetservice", "TargetService")
print("PROBE2-OK")

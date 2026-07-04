"""Integrate AI-generated images from assets/incoming/ into the project.

Converts to lossy WebP (Godot re-compresses to GPU formats at import, so
this only affects repo size), resizes to power-of-two where GPU mipmapping
benefits (tileables, portraits), and files each image in its permanent home.
Originals are removed from incoming/ after successful conversion.

Run:  python tools/pipeline/integrate_incoming.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
INCOMING = ROOT / "assets/incoming"

# prompt-id prefix (case-insensitive) -> (dest relative to assets/, size or None)
# size None = keep source dimensions.
MAPPING = {
    "p001": ("ui/title_key_art.webp", None),
    "p002": ("ui/menu_background.webp", None),
    "p003": ("portraits/sectoid.webp", (1024, 1024)),
    "p004": ("portraits/soldier_01.webp", (1024, 1024)),
    "p005": ("portraits/soldier_02.webp", (1024, 1024)),
    "p006": ("portraits/soldier_03.webp", (1024, 1024)),
    "p007": ("portraits/soldier_04.webp", (1024, 1024)),
    "p008": ("portraits/soldier_05.webp", (1024, 1024)),
    "p009": ("portraits/soldier_06.webp", (1024, 1024)),
    "p010": ("textures/ufo_hull_albedo.webp", (1024, 1024)),
    "p011": ("textures/alien_floor_albedo.webp", (1024, 1024)),
    "p012": ("textures/sectoid_skin_albedo.webp", (1024, 1024)),
}

QUALITY = 90


def main():
    if not INCOMING.exists():
        print("nothing to integrate")
        return
    done, skipped = 0, 0
    for src in sorted(INCOMING.iterdir()):
        if not src.is_file():
            continue
        key = src.name.lower()[:4]
        if key not in MAPPING:
            print(f"SKIP  {src.name} (no mapping — add one to MAPPING)")
            skipped += 1
            continue
        rel_dest, size = MAPPING[key]
        dest = ROOT / "assets" / rel_dest
        dest.parent.mkdir(parents=True, exist_ok=True)
        img = Image.open(src)
        if size and img.size != size:
            img = img.resize(size, Image.LANCZOS)
        img.save(dest, "WEBP", quality=QUALITY, method=6)
        print(f"OK    {src.name} -> {rel_dest} "
              f"({img.size[0]}x{img.size[1]}, {dest.stat().st_size // 1024} KB)")
        src.unlink()
        done += 1
    print(f"integrated {done}, skipped {skipped}")


main()

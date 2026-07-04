#!/usr/bin/env bash
# Fetch third-party assets that are gitignored (assets/third_party/).
# Everything here is CC0 or unrestricted. Safe to re-run; skips existing files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TP="$ROOT/assets/third_party"

fetch() { # fetch <dest> <url>
  local dest="$1" url="$2"
  if [ -s "$dest" ]; then echo "skip  $(basename "$dest")"; return; fi
  mkdir -p "$(dirname "$dest")"
  echo "fetch $(basename "$dest")"
  curl -sL --fail -o "$dest" "$url"
}

# --- CMU motion capture (BVH conversion, mirror: una-dinosauria/cmu-mocap) ---
CMU_RAW="https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master"
fetch "$TP/mocap/index.txt"        "$CMU_RAW/cmu-mocap-index-text.txt"
fetch "$TP/mocap/07_01_walk.bvh"   "$CMU_RAW/data/007/07_01.bvh"
fetch "$TP/mocap/02_01_walk.bvh"   "$CMU_RAW/data/002/02_01.bvh"
# More clips are added here as Phase 2 presentation work curates them.

# --- Poly Haven (CC0) --------------------------------------------------------
# Uses the Poly Haven API to resolve current CDN URLs.
ph_file() { # ph_file <asset> <jq-ish path: type res fmt> <dest>
  local asset="$1" kind="$2" res="$3" fmt="$4" dest="$5"
  if [ -s "$dest" ]; then echo "skip  $(basename "$dest")"; return; fi
  local url
  url=$(curl -sL "https://api.polyhaven.com/files/$asset" | python -c "
import json,sys
d=json.load(sys.stdin)
print(d['$kind']['$res']['$fmt']['url'])
" 2>/dev/null) || { echo "WARN: could not resolve $asset/$kind"; return; }
  mkdir -p "$(dirname "$dest")"
  echo "fetch $(basename "$dest")"
  curl -sL --fail -o "$dest" "$url"
}

# Daytime sky HDRI for battlescape lighting.
ph_file kloofendal_48d_partly_cloudy_puresky hdri 2k hdr \
  "$TP/polyhaven/hdri/sky_day_2k.hdr"

echo "done"

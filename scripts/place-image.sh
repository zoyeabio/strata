#!/usr/bin/env bash
# Place a source image into a site's per-page image directory with a size
# lint before writing anything.
#
# Usage:
#   ./scripts/place-image.sh \
#     --section journal \
#     --post example-post \
#     --file out/illustration-1.png \
#   --role illustration \
#     --site /path/to/site \
#     --environment production
#
# Copies --file to assets/images/{section}/{slug}/{filename} and prints the
# front matter reference (the bare filename) for a page bundle at
# content/{section}/{slug}/index.md.
#
# The size lint is config, not code: [params.build.minwidth] per role, and
# [params.image.og] for the social preview, which must be an exact match.
# scripts/lib/build_config.py resolves the theme defaults in config.toml
# merged with --site's own config, the same pair Hugo merges for rendering.
# A failing lint exits non-zero and writes nothing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SECTION=""
POST=""
FILE=""
ROLE="illustration"
SITE=""
ENVIRONMENT="production"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --section) SECTION="$2"; shift 2 ;;
    --post) POST="$2"; shift 2 ;;
    --file) FILE="$2"; shift 2 ;;
    --role) ROLE="$2"; shift 2 ;;
    --site) SITE="$2"; shift 2 ;;
    --environment) ENVIRONMENT="$2"; shift 2 ;;
    *) printf 'ERROR: unknown option %s\n' "$1" >&2; exit 2 ;;
  esac
done

if [ -z "$SECTION" ]; then printf 'ERROR: --section is required\n' >&2; exit 2; fi
if [ -z "$POST" ]; then printf 'ERROR: --post is required\n' >&2; exit 2; fi
if [ -z "$FILE" ]; then printf 'ERROR: --file is required\n' >&2; exit 2; fi

if [ -n "$SITE" ]; then
  SITE="$(cd "$SITE" && pwd)"
fi

# Size thresholds from config: the theme's config.toml merged with the
# site's own, resolved by scripts/lib/build_config.py — the same file pair
# Hugo merges when it renders. Needs python3 >= 3.11 for tomllib.
CFG_CMD=("$ROOT/scripts/lib/build_config.py" --environment "$ENVIRONMENT")
if [ -n "$SITE" ]; then CFG_CMD+=(--site "$SITE"); fi
if ! BUILD_CONFIG="$(python3 "${CFG_CMD[@]}")"; then
  printf 'ERROR: failed to resolve the build config (needs python3 >= 3.11)\n' >&2
  exit 2
fi
eval "$BUILD_CONFIG"

if [ ! -f "$FILE" ]; then
  printf 'ERROR: source image not found: %s\n' "$FILE" >&2
  exit 2
fi

case "$ROLE" in
  hero) MIN_W="$MIN_WIDTH_HERO" ;;
  illustration) MIN_W="$MIN_WIDTH_ILLUSTRATION" ;;
  card) MIN_W="$MIN_WIDTH_CARD" ;;
  og) MIN_W="$MIN_WIDTH_OG" ;;
  *) printf 'ERROR: unknown role %s (hero|illustration|card|og)\n' "$ROLE" >&2; exit 2 ;;
esac

BASE_NAME="$(basename "$FILE")"
DEST_DIR="${SITE:+$SITE/}assets/images/$SECTION/$POST"
DEST="$DEST_DIR/$BASE_NAME"

dims="$(python3 - "$FILE" "$ROLE" <<'PY'
import struct, sys
from pathlib import Path

path, role = sys.argv[1], sys.argv[2]
data = Path(path).read_bytes()
w = h = 0
if data.startswith(b'\x89PNG\r\n\x1a\n') and len(data) >= 24:
    w, h = struct.unpack('>II', data[16:24])
elif data.startswith(b'\xff\xd8'):
    i = 2
    while i + 9 < len(data):
        if data[i] != 0xFF:
            i += 1
            continue
        marker = data[i + 1]
        if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
            h, w = struct.unpack('>HH', data[i + 5:i + 9])
            break
        length = struct.unpack('>H', data[i + 2:i + 4])[0]
        i += 2 + length
elif data.startswith(b'GIF87a') or data.startswith(b'GIF89a'):
    w, h = struct.unpack('<HH', data[6:10])
elif data[:4] == b'RIFF' and data[8:12] == b'WEBP':
    if data[12:16] == b'VP8 ' and len(data) >= 30:
        w, h = struct.unpack('<HH', data[26:30])
        w &= 0x3FFF
        h &= 0x3FFF
    elif data[12:16] == b'VP8L' and len(data) >= 25:
        bits = data[21] | (data[22] << 8) | (data[23] << 16) | (data[24] << 24)
        w = (bits & 0x3FFF) + 1
        h = ((bits >> 14) & 0x3FFF) + 1
if not w or not h:
    print('FAIL: cannot read dimensions (png/jpeg/gif/webp supported)', file=sys.stderr)
    sys.exit(2)
print(f'{w} {h}')
PY
)"

W="${dims% *}"
H="${dims#* }"

if [ "$ROLE" = "og" ]; then
  if [ "$W" -ne "$OG_WIDTH" ] || [ "$H" -ne "$OG_HEIGHT" ]; then
    printf 'FAIL og image must be exactly %sx%s (got %sx%s)\n' \
      "$OG_WIDTH" "$OG_HEIGHT" "$W" "$H" >&2
    exit 1
  fi
elif [ "$W" -lt "$MIN_W" ]; then
  printf 'FAIL %s image must be at least %spx wide (got %sx%s)\n' \
    "$ROLE" "$MIN_W" "$W" "$H" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"
cp "$FILE" "$DEST"

printf 'ok   wrote %s\n' "$DEST"
printf 'ref  %s\n' "$BASE_NAME"
#!/usr/bin/env bash
# Builds test/fixture and asserts the image pipeline contract against the
# rendered HTML. Every assertion is a regression gate for the resolver,
# the ladder, the render hook and the head tags.
#
# Usage: scripts/smoke.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
OUT="$WORK/public"
trap 'rm -rf "$WORK"' EXIT
FAILURES=0

hugo --source "$ROOT/test/fixture" --destination "$OUT" --quiet

pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }

assert() { # assert <file> <regex> <label>
  if grep -qE "$2" "$OUT/$1" 2>/dev/null; then pass "$3"; else fail "$3"; fi
}

assert_not() { # assert_not <file> <regex> <label>
  if grep -qE "$2" "$OUT/$1" 2>/dev/null; then fail "$3"; else pass "$3"; fi
}

count_assert() { # count_assert <file> <regex> <n> <label>
  local n
  n=$(grep -cE "$2" "$OUT/$1" 2>/dev/null || true)
  if [ "$n" -eq "$3" ]; then pass "$4"; else fail "$4 (got $n, want $3)"; fi
}

# 1. section-flat asset resolves into a srcset ladder
assert 'section-a/index.html' 'srcset="[^"]*480w[^"]*800w' \
  'section-flat asset produces a 480/800 srcset'

# 2. per-page image directory resolves
assert 'section-a/nested/post/index.html' 'property="og:image" content="[^"]*nested[^"]*\.jpg"' \
  'per-page image directory resolves (og:image is a jpeg)'

# 3. markdown inline images go through the render hook, not a bare <img>
assert 'section-a/inline/index.html' 'srcset="[^"]*480w' \
  'inline markdown image carries a srcset'

# 4. a missing reference leaves no empty media wrapper (only the three
#    resolvable cards emit card__media; "missing" contributes none)
count_assert 'section-a/index.html' 'card__media' 3 'missing image leaves no empty card__media'

# 5. svg passes through untouched
assert 'section-a/vector/index.html' 'property="og:image" content="[^"]*\.svg"' \
  'svg is passed through, not processed'

# 6. og:image is a 1200x630 jpeg with an alt
assert 'section-a/flat/index.html' 'property="og:image:width" content="1200"' 'og:image width 1200'
assert 'section-a/flat/index.html' 'property="og:image:height" content="630"' 'og:image height 630'
assert 'section-a/flat/index.html' 'property="og:image:alt" content="Flat asset image"' 'og:image alt'

# 7. eager/lazy split follows eagerCardCount = 2
count_assert 'section-a/index.html' 'loading="eager"' 2 'exactly two eager card images'
assert 'section-a/index.html' 'fetchpriority="low"' 'later cards get fetchpriority=low'

# 8. the hero preload carries the same srcset as the hero <img>
assert 'section-a/flat/index.html' 'rel="preload"[^>]*imagesrcset="[^"]*480w' \
  'hero preload is emitted'
python3 - "$OUT" <<'PY'
import re
import sys
import urllib.parse
from pathlib import Path

out = Path(sys.argv[1])
html = (out / "section-a/flat/index.html").read_text()
preload = re.search(r'rel="preload"[^>]*imagesrcset="([^"]+)"', html)
hero = re.search(r'srcset="([^"]+)"[^>]*article-hero__image', html)
if not preload or not hero:
    print("FAIL hero preload or hero srcset missing", file=sys.stderr)
    sys.exit(1)
a = {part.strip() for part in urllib.parse.unquote(preload.group(1)).split(",")}
b = {part.strip() for part in hero.group(1).split(",")}
if a != b:
    print(f"FAIL hero preload srcset {a} != hero img srcset {b}", file=sys.stderr)
    sys.exit(1)
print("ok   hero preload srcset matches the hero img srcset")
PY

if [ "$FAILURES" -gt 0 ]; then
  printf 'smoke: %s failure(s)\n' "$FAILURES" >&2
  exit 1
fi
printf 'smoke: all assertions passed\n'

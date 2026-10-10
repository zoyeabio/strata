#!/usr/bin/env bash
# Builds test/fixture and asserts the theme contract against the rendered
# HTML: image resolver and ladder, sizes invariants, head tags, taxonomy,
# series, remote gating, shortcodes, production silence and build
# reproducibility. Every assertion is a regression gate; the script exits
# non-zero if any of them fails.
#
# Usage: scripts/smoke.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
OUT="$WORK/public"
OUT_REMOTE="$WORK/public-remote"
trap 'rm -rf "$WORK"' EXIT
FAILURES=0

hugo --source "$ROOT/test/fixture" --destination "$OUT" --quiet 2>"$WORK/build.stderr"

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

# 4. a missing reference leaves no empty media wrapper; flat, nested, vector,
#    gif and animated webp emit one each, the blocked remote card none
count_assert 'section-a/index.html' 'card__media' 5 'five cards render card__media'

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

# 8. the hero preload matches the hero <img> in srcset and sizes
assert 'section-a/flat/index.html' 'rel="preload"[^>]*imagesrcset="[^"]*480w' \
  'hero preload is emitted'
if hero_out=$(python3 - "$OUT" <<'PY'
import re
import sys
import urllib.parse
from pathlib import Path

html = (Path(sys.argv[1]) / "section-a/flat/index.html").read_text()
preload = re.search(r'rel="preload"[^>]*imagesrcset="([^"]+)"', html)
hero = re.search(r'srcset="([^"]+)"[^>]*article-hero__image', html)
preload_sizes = re.search(r'rel="preload"[^>]*imagesizes="([^"]+)"', html)
hero_sizes = re.search(r'sizes="([^"]+)"[^>]*article-hero__image', html)
failed = False
if not preload or not hero:
    print("FAIL hero preload srcset matches the hero img srcset")
    failed = True
else:
    a = {part.strip() for part in urllib.parse.unquote(preload.group(1)).split(",")}
    b = {part.strip() for part in hero.group(1).split(",")}
    if a != b:
        print(f"FAIL hero preload srcset differs: {sorted(a)} != {sorted(b)}")
        failed = True
    else:
        print("ok   hero preload srcset matches the hero img srcset")
if not preload_sizes or not hero_sizes:
    print("FAIL hero preload imagesizes matches the hero img sizes")
    failed = True
elif preload_sizes.group(1) != hero_sizes.group(1):
    print(f"FAIL hero preload imagesizes differs: {preload_sizes.group(1)} != {hero_sizes.group(1)}")
    failed = True
else:
    print("ok   hero preload imagesizes matches the hero img sizes")
sys.exit(1 if failed else 0)
PY
); then
  printf '%s\n' "$hero_out"
else
  printf '%s\n' "$hero_out"
  FAILURES=$((FAILURES + 1))
fi

# 9. taxonomy overview lists every term with its count (text mode by default)
assert 'tags/index.html' 'term-text__link' 'taxonomy overview renders term links'
count_assert 'tags/index.html' 'term-text__count' 2 'both terms show a count'

# 10. a term page lists the tagged articles
count_assert 'tags/alpha/index.html' 'card card--' 2 'term alpha lists two article cards'
assert 'tags/beta/index.html' 'card card--' 'term beta lists its article cards'

# 11. the 404 page links home and to the first menu item, never a hardcoded path
assert '404.html' 'not-found__code' '404 page renders'
assert '404.html' 'href="/"' '404 links home'

# 12. list cards use the computed grid preset (fixture sets [list] cardView)
assert 'section-a/index.html' 'sizes="[^"]*calc\(\(100vw - 128px\) / 2\)' \
  'grid cards carry the computed grid sizes'

# 13. animated webp passes through untouched: the original file, no variants
assert 'section-a/anim/index.html' 'src="/images/section-a/anim\.webp"' \
  'animated webp renders as the original file'
assert_not 'section-a/anim/index.html' '480w' 'animated webp produces no variants'

# 14. gif bypasses processing entirely
assert 'section-a/pixel/index.html' 'src="/images/section-a/pixel\.gif"' \
  'gif passes through untouched'
assert_not 'section-a/pixel/index.html' 'srcset=' 'gif carries no srcset'

# 15. remote images stay out unless the site opts in
assert_not 'section-a/remote/index.html' 'example\.com' \
  'remote image is absent when allowRemoteImages is off'
HUGO_PARAMS_ALLOWREMOTEIMAGES=true hugo --source "$ROOT/test/fixture" \
  --destination "$OUT_REMOTE" --quiet
if grep -qE 'example\.com' "$OUT_REMOTE/section-a/remote/index.html" 2>/dev/null; then
  pass 'remote image renders when allowRemoteImages is on'
else
  fail 'remote image renders when allowRemoteImages is on'
fi

# 16. series navigation marks the current article and links the sibling
assert 'section-a/series-a/index.html' 'series__current[^>]*>Series part one' \
  'series marks the current article'
assert 'section-a/series-a/index.html' 'series__link" href="/section-a/series-b/' \
  'series links the sibling article'

# 17. production builds log no image warnings (warnf is server-only)
if grep -qE 'image not found|remote image skipped' "$WORK/build.stderr"; then
  fail 'production build logs no image warnings'
else
  pass 'production build logs no image warnings'
fi

# 18. sizes invariants across the whole site: a fixed width declared for a
#     min-width range must fit inside that range, and the fallback may never
#     be a bare 100vw (PLAN 2.3)
if sizes_out=$(python3 - "$OUT" <<'PY'
import re
import sys
from pathlib import Path

out = Path(sys.argv[1])
overstated = []
bare = []
for f in sorted(out.rglob("*.html")):
    for attr in re.findall(r'(?:imagesizes|sizes)="([^"]+)"', f.read_text()):
        for lo, px in re.findall(r'\(min-width:(\d+)px\)\s+(\d+)px', attr):
            if int(px) > int(lo):
                overstated.append(f"{f.relative_to(out)}: {px}px at min-width {lo}px")
        stripped = attr
        while True:
            reduced = re.sub(r'\([^()]*\)', '', stripped)
            if reduced == stripped:
                break
            stripped = reduced
        if '100vw' in stripped:
            bare.append(f"{f.relative_to(out)}: {attr}")
failed = False
if overstated:
    print("FAIL sizes never overstate a breakpoint")
    for item in overstated:
        print(f"  {item}")
    failed = True
else:
    print("ok   sizes never overstate a breakpoint")
if bare:
    print("FAIL sizes fallback is never a bare 100vw")
    for item in bare:
        print(f"  {item}")
    failed = True
else:
    print("ok   sizes fallback is never a bare 100vw")
sys.exit(1 if failed else 0)
PY
); then
  printf '%s\n' "$sizes_out"
else
  printf '%s\n' "$sizes_out"
  FAILURES=$((FAILURES + 1))
fi

# 19. shortcodes: figure goes through the pipeline with the built-in's
#     caption structure, and quality= produces its own variant set
assert 'section-a/shortcodes/index.html' '<figure class="figure">' \
  'figure renders the base figure element'
assert 'section-a/shortcodes/index.html' '<figure class="figure extra">' \
  'figure appends the user class'
assert 'section-a/shortcodes/index.html' 'alt="A flat photo"' \
  'figure falls back to the plainified caption for alt'
assert 'section-a/shortcodes/index.html' '<figcaption>' 'figure emits a figcaption'
assert 'section-a/shortcodes/index.html' '<h4>With a title</h4>' \
  'figure renders the title as an h4 inside the figcaption'
assert 'section-a/shortcodes/index.html' '<a href="/section-a/flat/" target="_blank" rel="noopener">' \
  'figure wraps the image in the requested link'
assert 'section-a/shortcodes/index.html' 'width="400" height="300"' \
  'figure honours explicit width/height over the intrinsic size'
count_assert 'section-a/shortcodes/index.html' 'sizes="\(min-width:853px\) 720px' 5 \
  'three figures and two slides carry the text sizes'
count_assert 'section-a/shortcodes/index.html' 'loading="eager"' 5 \
  'four list cards plus the first slide load eagerly'
if qual_out=$(python3 - "$OUT" <<'PY'
import re
import sys
from pathlib import Path

html = (Path(sys.argv[1]) / "section-a/shortcodes/index.html").read_text()
urls = set(re.findall(r'(photo-flat_hu_[a-f0-9]+\.webp) 1280w', html))
if len(urls) == 2:
    print("ok   figure quality= writes its own variant set")
    sys.exit(0)
print(f"FAIL figure quality= writes its own variant set (got {sorted(urls)})")
sys.exit(1)
PY
); then
  printf '%s\n' "$qual_out"
else
  printf '%s\n' "$qual_out"
  FAILURES=$((FAILURES + 1))
fi

# 20. content shortcodes: embedded card, both list branches, icon
count_assert 'section-a/shortcodes/index.html' 'card card--inline' 1 \
  'content/article embeds an inline card'
assert 'section-a/shortcodes/index.html' 'card__summary">Flat body' \
  'the embedded card shows its summary when showSummary=true'
assert 'section-a/shortcodes/index.html' 'shortcode-list--grid' \
  'cardView=true selects the grid branch'
count_assert 'section-a/shortcodes/index.html' 'card card--grid' 2 \
  'the grid list renders two cards'
assert 'section-a/shortcodes/index.html' 'shortcode-list--rows' \
  'cardView=false selects the row branch even as a string'
count_assert 'section-a/shortcodes/index.html' 'card card--row' 2 \
  'the row list renders two cards'
assert 'section-a/shortcodes/index.html' '<span class="icon" aria-hidden="true"><svg' \
  'icon inlines the svg from assets/icons'

# 21. interactive shortcodes: email, cta, contact form, carousel
assert 'section-a/shortcodes/index.html' 'href="mailto:info&#64;example.com"' \
  'email link is entity-obfuscated and needs no script'
assert 'section-a/shortcodes/index.html' '<div class="cta not-prose">' \
  'cta renders the banner wrapper'
assert 'section-a/shortcodes/index.html' 'class="cta__button" href="/contact/"' \
  'cta renders the button with its target'
assert 'section-a/shortcodes/index.html' 'action="/api/contact"' \
  'contact form posts to the default endpoint'
assert 'section-a/shortcodes/index.html' 'name="hp_name"' \
  'contact form keeps the honeypot'
assert 'section-a/shortcodes/index.html' 'var id = "contact-form-' \
  'the contact script targets its own instance id'
assert 'section-a/shortcodes/index.html' 'data-interval="1500"' \
  'carousel carries the configured interval'
assert 'section-a/shortcodes/index.html' 'aspect-ratio: 16 / 9' \
  'carousel keeps the requested aspect ratio'
count_assert 'section-a/shortcodes/index.html' 'data-slide-to="[0-9]"' 2 \
  'carousel renders two indicator buttons'
assert 'section-a/shortcodes/index.html' 'class="carousel__caption">Inline image' \
  'carousel captions match by file name'

# 22. layout shortcodes: computed template and single class set
assert 'section-a/shortcodes/index.html' 'mgrid mgrid--cols-2' \
  'multi-col renders the container with its column modifier'
assert 'section-a/shortcodes/index.html' 'style="[^"]*mgrid-template: 2fr 1fr' \
  'multi-col honours the ratio parameter'
assert 'section-a/shortcodes/index.html' 'class="mcol mcol--first"' \
  'col-left renders the first-column class set'
assert 'section-a/shortcodes/index.html' 'class="mcol mcol--last"' \
  'col-right renders the last-column class set'

# 23. build reproducibility: two independent builds of the same tree are
#     byte-identical, so no template may leak now/rand/unsorted iteration
#     into the output — a swapping id or timestamp slips past every content
#     assertion above and would blind the diff-build gate to real changes
OUT_REPRO="$WORK/public-repro"
hugo --source "$ROOT/test/fixture" --destination "$OUT_REPRO" --quiet \
  2>"$WORK/build-repro.stderr"
if diff -r -q "$OUT" "$OUT_REPRO" >"$WORK/repro.diff" 2>&1; then
  pass 'two builds are byte-identical'
else
  fail 'two builds are byte-identical'
  awk 'NR<=20{print "  " $0}' "$WORK/repro.diff" >&2
fi

if [ "$FAILURES" -gt 0 ]; then
  printf 'smoke: %s failure(s)\n' "$FAILURES" >&2
  exit 1
fi
printf 'smoke: all assertions passed\n'

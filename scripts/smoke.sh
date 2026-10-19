#!/usr/bin/env bash
# Builds test/fixture and asserts the theme contract against the rendered
# HTML: image resolver and ladder, sizes invariants, head tags, taxonomy,
# series, remote gating, shortcodes, production silence, stylesheet wiring
# (link count, fingerprint, pipeline output, sizes-ladder parity,
# template class-token coverage), and build reproducibility. Every assertion
# is a regression gate; the script exits non-zero if any of them fails.
#
# Usage: scripts/smoke.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The gate scripts lean on the standard library's tomllib (3.11+) to resolve
# the same config pair Hugo merges. A system python3 below that dies with a
# traceback mid-script, so name the requirement before any build output.
if ! python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)'; then
  printf 'ERROR: python3 >= 3.11 is required (stdlib tomllib)\n' >&2
  exit 2
fi
WORK="$(mktemp -d)"
OUT="$WORK/public"
OUT_REMOTE="$WORK/public-remote"
OUT_NOSITEDESC="$WORK/public-nositedesc"
OUT_QUALITY="$WORK/public-quality"
OUT_MEASURE="$WORK/public-measure"
OUT_NOSUMMARY="$WORK/public-nosummary"
OUT_NOTAB="$WORK/public-notab"
OUT_ROBOTS="$WORK/public-robots"
OUT_DRAFTS="$WORK/public-drafts"
trap 'rm -rf "$WORK"' EXIT
FAILURES=0

# css.TailwindCSS shells out to the Tailwind v4 CLI, which must be on PATH
# (fail fast — without it every assertion below is noise). Since Hugo 0.161.0
# Hugo runs it through node, so the npm CLI has to be reachable too. The repo
# keeps node_modules here; test/fixture sits underneath, so @plugin resolution
# walks up from either the source dir or the stylesheet and finds it.
if [ -d "$ROOT/node_modules/.bin" ]; then
  PATH="$ROOT/node_modules/.bin:$PATH"
  export PATH
fi
if ! command -v tailwindcss >/dev/null 2>&1; then
  echo 'FAIL tailwindcss not on PATH — run npm install (see README)' >&2
  exit 1
fi

# A build failure has to surface its own message. `--quiet` makes Hugo swallow
# even a fatal error, and stderr is captured for the assertions below, so
# `set -e` would otherwise exit with the only diagnostic already deleted by
# the trap — a failing build printed nothing but a line number.
if ! hugo --source "$ROOT/test/fixture" --destination "$OUT" --quiet 2>"$WORK/build.stderr"; then
  printf 'FAIL fixture build failed\n' >&2
  hugo --source "$ROOT/test/fixture" --destination "$WORK/rebuild" || true
  exit 1
fi
hugo --source "$ROOT/test/fixture" --environment measure \
  --destination "$OUT_MEASURE" --quiet
hugo --source "$ROOT/test/fixture" --environment nosummary \
  --destination "$OUT_NOSUMMARY" --quiet
hugo --source "$ROOT/test/fixture" --environment notab \
  --destination "$OUT_NOTAB" --quiet

pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }

assert() { # assert <file> <regex> <label>
  if grep -qE "$2" "$OUT/$1" 2>/dev/null; then pass "$3"; else fail "$3"; fi
}

assert_not() { # assert_not <file> <regex> <label>
  if grep -qE "$2" "$OUT/$1" 2>/dev/null; then fail "$3"; else pass "$3"; fi
}

# assert_at reads a build written outside $OUT, where assert's fixed root
# would silently look for a page the build never produced
assert_at() { # assert_at <dir> <file> <regex> <label>
  if grep -qE "$3" "$1/$2" 2>/dev/null; then pass "$4"; else fail "$4"; fi
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

# 4. a missing reference leaves no empty media wrapper; flat, vector, gif and
#    animated webp emit one each; the blocked remote card and the nested
#    section card none
count_assert 'section-a/index.html' 'card__media' 4 'four cards render card__media'

# 5. svg passes through untouched
assert 'section-a/vector/index.html' 'property="og:image" content="[^"]*\.svg"' \
  'svg is passed through, not processed'

# 5b. a page with no featureimage key still finds an image: the vector leaf
#     bundle carries cover.svg, and hero, card and social output all take it
assert 'section-a/vector/index.html' 'class="page-hero__image"' \
  'a bundle cover renders the hero with no featureimage key'
assert 'section-a/vector/index.html' 'property="og:image" content="[^"]*cover\.svg"' \
  'social output takes the bundle cover too'

# 6. og:image is a 1200x630 jpeg with an alt
assert 'section-a/flat/index.html' 'property="og:image:width" content="1200"' 'og:image width 1200'
assert 'section-a/flat/index.html' 'property="og:image:height" content="630"' 'og:image height 630'
assert 'section-a/flat/index.html' 'property="og:image:alt" content="Flat asset image"' 'og:image alt'

# 7. eager/lazy split follows eagerCardCount = 2. The hero is eager too but it
#    is not a card, so count inside card tags only; the attributes sit one per
#    line, so no single regex can span a tag here.
if eager_out=$(python3 - "$OUT" <<'PY'
import re
import sys
from pathlib import Path

html = (Path(sys.argv[1]) / "section-a/index.html").read_text()
cards = [tag for tag in re.findall(r'<img\b[^>]*>', html) if 'card__image' in tag]
eager = sum('loading="eager"' in tag for tag in cards)
lazy = sum('loading="lazy"' in tag for tag in cards)
failed = len(cards) != 4 or eager != 2 or lazy != 2
if failed:
    print(f"FAIL exactly two eager card images (cards {len(cards)}, eager {eager}, lazy {lazy})")
else:
    print("ok   exactly two eager card images")
sys.exit(1 if failed else 0)
PY
); then
  printf '%s\n' "$eager_out"
else
  printf '%s\n' "$eager_out"
  FAILURES=$((FAILURES + 1))
fi
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
hero = re.search(r'srcset="([^"]+)"[^>]*page-hero__image', html)
preload_sizes = re.search(r'rel="preload"[^>]*imagesizes="([^"]+)"', html)
hero_sizes = re.search(r'sizes="([^"]+)"[^>]*page-hero__image', html)
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
count_assert 'tags/index.html' 'term-text__count' 3 'all three terms show a count'

# 10. a term page lists the tagged articles
count_assert 'tags/alpha/index.html' 'card card--' 2 'term alpha lists two article cards'
assert 'tags/beta/index.html' 'card card--' 'term beta lists its article cards'

# 11. the 404 page links home and to the first menu item, never a hardcoded path
assert '404.html' 'not-found__code' '404 page renders'
assert '404.html' 'href="/"' '404 links home'
assert 'index.html' 'rel="icon" href="/favicon\.ico" sizes="any"' \
  'the default favicon includes an ico fallback'
assert 'index.html' 'rel="icon" type="image/svg\+xml" href="/favicon\.svg"' \
  'the default favicon prefers svg'
assert 'index.html' 'rel="apple-touch-icon" sizes="180x180"' \
  'the default favicon includes an apple touch icon'
assert 'index.html' 'rel="mask-icon" href="/safari-pinned-tab\.svg" color="#183229"' \
  'the default favicon includes a pinned-tab mask'
if [ -s "$OUT/favicon.ico" ] && [ -s "$OUT/favicon.svg" ] && \
   [ -s "$OUT/apple-touch-icon.png" ] && \
   [ -s "$OUT/android-chrome-192x192.png" ] && \
   [ -s "$OUT/android-chrome-512x512.png" ] && \
   [ -s "$OUT/safari-pinned-tab.svg" ]; then
  pass 'the default favicon asset set ships'
else
  fail 'the default favicon asset set ships'
fi

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

# 15. remote images stay out unless the site opts in. The opt-in comes from an
#      environment overlay (config/remote/), not HUGO_PARAMS_* — Hugo dropped
#      those env-var overrides after 0.151
assert_not 'section-a/remote/index.html' 'example\.com' \
  'remote image is absent when allowRemoteImages is off'
hugo --source "$ROOT/test/fixture" --environment remote \
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
#     be a bare 100vw
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
#     caption structure
assert 'notice/index.html' 'sizes="\(min-width:1280px\) 1024px' \
  'wide-page content images declare the full content frame'
assert_not 'notice/index.html' 'sizes="[^\"]*min\(calc\([^\"]*, 720px\)' \
  'wide-page content images do not advertise the article reading measure'
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
assert 'section-a/shortcodes/index.html' '<div class="map">' \
  'map renders its box'
assert 'section-a/shortcodes/index.html' 'title="Shanghai office map" loading="lazy"' \
  'map frame carries its label and defers loading'
assert 'section-a/shortcodes/index.html' 'src="https://maps.google.com/maps\?q=Shanghai' \
  'map passes the embed URL through'
count_assert 'section-a/shortcodes/index.html' 'loading="eager"' 7 \
  'five list cards plus two first slides load eagerly'
# Quality is site-wide, so two figures sharing a role cannot write the same
# width twice at two qualities. One file per (image, width) across the build.
if qual_out=$(python3 - "$OUT" <<'PY'
import re
import sys
from collections import defaultdict
from pathlib import Path

pairs = defaultdict(set)
for page in Path(sys.argv[1]).rglob("*.html"):
    for srcset in re.findall(r'srcset="([^"]+)"', page.read_text(encoding="utf-8")):
        for url, w in re.findall(r'([^\s",]*?_hu_[a-f0-9]+\.[a-z0-9]+)\s+(\d+)w', srcset):
            base = re.sub(r'_hu_[a-f0-9]+\.[a-z0-9]+$', '', url.split("/")[-1])
            pairs[(base, int(w))].add(url)
dupes = {f"{b} {w}w": sorted(v) for (b, w), v in pairs.items() if len(v) > 1}
if dupes:
    print(f"FAIL a width is stored twice ({dupes})")
    sys.exit(1)
print(f"ok   one file per image and width ({len(pairs)} pairs, no duplicates)")
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
assert 'section-a/shortcodes/index.html' 'class="shortcode-list">' \
  'cardView=false selects the row branch (base class only)'
count_assert 'section-a/shortcodes/index.html' 'card card--row' 3 \
  'the row lists render three cards'
count_assert 'section-a/shortcodes/index.html' 'card__summary' 5 \
  'list and embedded cards render their summaries (summary=false suppresses one)'
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
assert 'section-a/shortcodes/index.html' \
  'data-contact-form data-max-bytes="1000" data-cooldown="10" data-min-fill="3"' \
  'the contact form publishes its byte limit, cooldown and min fill as markup'
assert 'section-a/shortcodes/index.html' \
  'src="[^"]*js/contact\.[0-9a-f]+\.js" integrity="sha512-' \
  'the contact script loads fingerprinted with SRI'
if grep -q 'data-cooldown' "$OUT"/js/contact.*.js && grep -q 'form_ts' "$OUT"/js/contact.*.js; then
  pass 'the contact script reads the cooldown and writes form_ts from markup'
else
  fail 'the contact script reads the cooldown and writes form_ts from markup'
fi
assert 'section-a/shortcodes/index.html' 'data-interval="1500"' \
  'carousel carries the configured interval'
assert 'section-a/shortcodes/index.html' 'aspect-ratio: 16 / 9' \
  'carousel keeps the requested aspect ratio'
count_assert 'section-a/shortcodes/index.html' 'data-slide-to="[0-9]"' 3 \
  'carousels render three indicator buttons'
assert 'section-a/shortcodes/index.html' 'class="carousel__caption">Inline image' \
  'carousel captions match by file name'
assert 'section-a/shortcodes/index.html' 'alt="A person working at a desk"' \
  'carousel takes a per-slide alt from the alts map'
assert 'section-a/shortcodes/index.html' 'alt="Flat photo"' \
  'a carousel slide without an alt falls back to its caption'
assert 'section-a/shortcodes/index.html' 'alt="carousel image 1"' \
  'a carousel slide with neither falls back to a positional label'
assert 'section-a/shortcodes/index.html' 'carousel__frame--contain' \
  'fit="contain" marks the slide frame'
assert 'section-a/shortcodes/index.html' 'aspect-ratio: 4 / 3' \
  'a second carousel takes its own aspect ratio'
# Quality is site-wide config and there is no per-figure override, so an
# [params.image].quality overlay must re-encode every variant of every figure.
hugo --source "$ROOT/test/fixture" --environment quality \
  --destination "$OUT_QUALITY" --quiet
if FIGURE_Q="$(python3 - "$OUT" "$OUT_QUALITY" <<'PY'
import re
import sys
from pathlib import Path

def variants(out, alt):
    page = (out / "section-a/shortcodes/index.html").read_text(encoding="utf-8")
    tag = re.search(r'<img[^>]*alt="%s"[^>]*>' % re.escape(alt), page).group(0)
    srcset = re.search(r'srcset="([^"]+)"', tag)
    return frozenset(re.findall(r'([\w.-]+_hu_[a-f0-9]+\.[a-z0-9]+)', srcset.group(1))) if srcset else frozenset()

base, quality = Path(sys.argv[1]), Path(sys.argv[2])
changed = variants(base, "Inline illustration") != variants(quality, "Inline illustration")
print("changed=%s" % changed)
PY
)"; then
  case "$FIGURE_Q" in
    "changed=True") pass 'an [params.image].quality overlay re-encodes every figure variant' ;;
    *) fail "an [params.image].quality overlay re-encodes every figure variant ($FIGURE_Q)" ;;
  esac
else
  fail 'an [params.image].quality overlay re-encodes every figure variant'
fi

# 22. layout shortcodes: computed template and single class set
assert 'section-a/shortcodes/index.html' 'class="mgrid"' \
  'multi-col renders the container'
assert 'section-a/shortcodes/index.html' 'style="[^"]*mgrid-template: 2fr 1fr' \
  'multi-col honours the ratio parameter'
count_assert 'section-a/shortcodes/index.html' 'class="mcol"' 2 \
  'columns render the mcol class set'

# 23. build reproducibility: two independent builds of the same tree are
#     byte-identical, so no template may leak now/rand/unsorted iteration
#     into the output — a swapping id or timestamp slips past every content
#     assertion above and would only ever show up as an unexplained diff
OUT_REPRO="$WORK/public-repro"
hugo --source "$ROOT/test/fixture" --destination "$OUT_REPRO" --quiet \
  2>"$WORK/build-repro.stderr"
if diff -r -q "$OUT" "$OUT_REPRO" >"$WORK/repro.diff" 2>&1; then
  pass 'two builds are byte-identical'
else
  fail 'two builds are byte-identical'
  awk 'NR<=20{print "  " $0}' "$WORK/repro.diff" >&2
fi

# 24. the stylesheet comes from the in-process Tailwind pipeline, not a
#     committed bundle: no css/compiled reference may survive, and the built
#     theme CSS must carry a component rule only the sources provide
if grep -rq 'css/compiled' "$ROOT/layouts" "$ROOT/assets/css/main.css" 2>/dev/null; then
  fail 'stale css/compiled reference survives in layouts or CSS entry'
else
  pass 'no css/compiled references remain'
fi
theme_built=$(ls "$OUT"/css/theme*.css 2>/dev/null | head -1 || true)
if [ -n "$theme_built" ] && grep -q 'card__summary' "$theme_built"; then
  pass 'built theme CSS carries component rules (pipeline ran)'
else
  fail 'built theme CSS carries component rules (pipeline ran)'
fi

# 25. one stylesheet link per page: scheme and bundle travel as a single
#     minified, fingerprinted resource (fixture sets no customCSS)
count_assert 'section-a/flat/index.html' 'rel="stylesheet"' 1 \
  'exactly one stylesheet link'
assert 'section-a/flat/index.html' 'rel="stylesheet"[^>]*integrity="sha512-' \
  'stylesheet is fingerprinted'
assert 'index.html' 'rel="stylesheet"' 'home page links the stylesheet'

# 26. sizes ladder matches the CSS: every rung the presets emit
#     must correspond to a real container width in the stylesheet
css_assert() { # css_assert <regex> <label>
  local f
  f=$(ls "$OUT"/css/theme*.css 2>/dev/null | head -1 || true)
  if [ -n "$f" ] && grep -qE -e "$1" "$f"; then pass "$2"; else fail "$2"; fi
}

css_assert_not() { # css_assert_not <regex> <label>
  local f
  f=$(ls "$OUT"/css/theme*.css 2>/dev/null | head -1 || true)
  if [ -z "$f" ]; then fail "$2"; return; fi
  if grep -qE -e "$1" "$f"; then fail "$2"; else pass "$2"; fi
}
css_assert_not 'contact-form\{[^}]*max-width' \
  'the contact form fills its content column'
css_assert 'prose\{[^}]*max-width:var\(--prose-measure,720px\)' 'prose caps at the configured measure (default 720px)'
css_assert 'prose\{[^}]*margin-inline:auto' 'the reading column is centred, not left against the frame'
assert 'section-a/shortcodes/index.html' 'min-width:640px\) 240px' \
  'row thumb requests a 240px image at the fixed column width'
css_assert 'repeat\(3,minmax\(0,1fr\)\)' 'three columns from 853px (grid preset)'
css_assert 'repeat\(2,minmax\(0,1fr\)\)' 'two columns from 640px (grid preset)'
css_assert '@media\(min-width:853px\)\{:root\{--site-gutter:96px' \
  'gutter rung 96px sits at the 853px breakpoint'
css_assert ':root\{--site-gutter:24px;--site-content:1024px;--brand-logo-height' \
  'base gutter 24px and content cap 1024px'
css_assert '@media\(min-width:640px\)\{:root\{--site-gutter:56px' \
  'gutter rung 56px sits at the 640px breakpoint'
css_assert '@media\(min-width:1024px\)\{:root\{--site-gutter:128px' \
  'gutter rung 128px sits at the 1024px breakpoint'
css_assert '--site-accent:#295f8f' 'default scheme accent is linked in'
css_assert '--site-page-bg:#12171d' 'the dark block ships its own ground'
css_assert '--site-accent-fg:#6ea3d4' 'the dark block ships a separate accent foreground'
css_assert 'color-mix\(in srgb,var\(--text\) 4%,var\(--page-bg\)' \
  'surfaces derive from --text and survive the tailwind pass'
css_assert 'color-mix\(in srgb,var\(--site-accent\) 18%,var\(--page-bg\)' \
  'the soft selection tint derives from the accent'
css_assert '\--accent-fg:var\(--site-accent-fg,[[:space:]]*var\(--site-accent\)' \
  'the accent foreground falls back to the accent in light'
css_assert_not '\--site-accent-soft|\--site-surface-tint' \
  'no scheme-owned decorative token leaks into the output'
count_assert 'section-a/shortcodes/index.html' \
  'min\(calc\(100vw - 112px\), 720px\)' 7 \
  'text preset caps every body image and loop clone at the reading measure'
assert_at "$OUT_MEASURE" 'section-a/shortcodes/index.html' \
  'min\(calc\(100vw - 112px\), 800px\)' \
  'text image sizes follow an 800px readingMeasure override'

# 27. every class token the templates emit is defined in the shipped CSS
#     (accepts .token or [class~="token"]; {{ }} inside class attrs is cut
#     so concatenations like card--{{ $preset }} contribute a prefix that
#     must still match at least one rule). Author-supplied class parameters
#     that pass through a shortcode untouched are out of scope by design.
if classes_out=$(python3 - "$OUT" "$ROOT" <<'PY'
import re, sys, pathlib
out = pathlib.Path(sys.argv[1])
root = pathlib.Path(sys.argv[2])
bundle = next(out.glob('css/theme*.css'), None)
if bundle is None:
    print('FAIL built theme CSS missing')
    sys.exit(1)
css = bundle.read_text()
tokens, prefixes = set(), set()
for p in (root / 'layouts').rglob('*.html'):
    for m in re.finditer(r'class="([^"]*)"', p.read_text()):
        cleaned = re.sub(r'\{\{.*?\}\}', ' ', m.group(1))
        for tok in cleaned.split():
            if tok.endswith('-'):
                prefixes.add(tok)
            else:
                tokens.add(tok)
missing, bad_prefix = [], []
for tok in sorted(tokens):
    esc = re.escape(tok)
    if not re.search(r'\.' + esc + r'(?![\w-])|\[class~="' + esc + r'"\]', css):
        missing.append(tok)
for pre in sorted(prefixes):
    if not re.search(r'\.' + re.escape(pre) + r'[\w-]+(?![\w-])', css):
        bad_prefix.append(pre)
if missing or bad_prefix:
    for t in missing:
        print(f'FAIL class token "{t}" has no CSS rule')
    for t in bad_prefix:
        print(f'FAIL dynamic prefix "{t}*" matches no CSS rule')
    sys.exit(1)
print(f'all {len(tokens)} class tokens and {len(prefixes)} dynamic prefixes are styled')
PY
); then
  pass "class coverage: $classes_out"
else
  printf '%s\n' "$classes_out" >&2
  fail 'every template class token is defined in the shipped CSS'
fi

# 28. cascade layer order: parse every @layer statement per the CSS spec
#     (first appearance fixes the position) and assert the strata layers sit
#     after utilities — a reordering flips the typography plugin's defaults
#     above strata-base (pre loses its mono font, .prose falls back to 65ch)
if layer_out=$(python3 - "$OUT" <<'PY'
import re, sys, pathlib
out = pathlib.Path(sys.argv[1])
bundle = next(out.glob('css/theme*.css'), None)
text = bundle.read_text() if bundle else ''
order = []
for m in re.finditer(r'@layer\s+([^;{]+);', text):
    for name in m.group(1).split(','):
        name = name.strip()
        if name and name not in order:
            order.append(name)
if 'utilities' in order and all(
    order.index(n) > order.index('utilities')
    for n in order if n.startswith('strata-')
):
    print(' < '.join(order))
    sys.exit(0)
print('FAIL', file=sys.stderr)
sys.exit(1)
PY
); then
  pass "strata layers registered after utilities ($layer_out)"
else
  fail 'strata layers registered after utilities'
fi

# 29. values that must WIN the cascade, not merely exist: the typography
#     plugin also styles pre in the utilities layer; only cascade order
#     (assertion 28) keeps the strata rule effective, this pins the values
css_assert 'pre\{font-family:var\(--font-mono\);font-size:13px' \
  'pre rule carries mono 13px (strata-base over utilities)'
css_assert 'prose\{[^}]*max-width:var\(--prose-measure,720px\);margin-inline:auto' \
  '.prose rule carries the measure and centring, not the plugin 65ch'

# 30. taxonomy links are real pages: tags resolve through GetTerms, so the
#     href must equal the term's own URL even for punctuation ("Sci & Tech"
#     slugs to sci--tech, not what naive string concat would produce), and
#     the series nav must never point at a page that was not built
if tax_out=$(python3 - "$OUT" <<'PY'
import sys, pathlib, re, urllib.parse
out = pathlib.Path(sys.argv[1])
missing = []
checked = 0
for page in out.rglob('*.html'):
    text = page.read_text(errors='ignore')
    for m in re.finditer(r'class="article__tag" href="([^"]+)"', text):
        href = urllib.parse.urlparse(m.group(1)).path
        checked += 1
        if not (out / href.lstrip('/') / 'index.html').exists():
            missing.append(f'{page.relative_to(out)}: tag {href}')
    for m in re.finditer(r'class="series__link" href="([^"]+)"', text):
        href = urllib.parse.urlparse(m.group(1)).path
        checked += 1
        if not (out / href.lstrip('/') / 'index.html').exists():
            missing.append(f'{page.relative_to(out)}: series {href}')
    for m in re.finditer(r'class="article__author" href="([^"]+)"', text):
        # A mailto byline is an address, not a taxonomy page: entity-encoded
        # on purpose, so there is no page to resolve it against.
        if m.group(1).startswith('mailto:'):
            continue
        href = urllib.parse.urlparse(m.group(1)).path
        checked += 1
        if not (out / href.lstrip('/') / 'index.html').exists():
            missing.append(f'{page.relative_to(out)}: author {href}')
if missing:
    for line in missing:
        print('FAIL', line, file=sys.stderr)
    sys.exit(1)
if checked == 0:
    print('FAIL no taxonomy links rendered — GetTerms returned nothing', file=sys.stderr)
    sys.exit(1)
print(f'{checked} taxonomy links')
PY
); then
  pass "every tag, series and author link points at a built page ($tax_out)"
else
  fail 'every tag, series and author link points at a built page'
fi

# 30b. no crawlable email address anywhere in the text output: a bare @ in
#     a mailto href means some outlet skipped partials/href.html, and a full
#     email-shaped token in any file (HTML, XML, JSON, TXT, JS, CSS, manifest)
#     means some outlet leaked one without a link at all — sitemap, feed,
#     search index and every future export pass through the same net. &#64;
#     decodes only when a reader follows the link; share links (mailto:?body=…)
#     carry no address and must stay unharmed.
if sweep_out=$(python3 - "$OUT" <<'PY'
import sys, pathlib, re
out = pathlib.Path(sys.argv[1])
bad = []
raw_href = re.compile(r'href="mailto:[^"]*@', re.I)
address = re.compile(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')
text_exts = {'.html', '.xml', '.json', '.txt', '.js', '.css', '.svg', '.webmanifest'}
files = 0
for page in out.rglob('*'):
    if not page.is_file() or page.suffix not in text_exts:
        continue
    files += 1
    text = page.read_text(errors='ignore')
    for pat, why in ((raw_href, 'bare @ in mailto href'),
                     (address, 'email-shaped address')):
        hit = pat.search(text)
        if hit:
            bad.append(f'{page.relative_to(out)} [{why}]: {hit.group(0)}')
if bad:
    for line in bad[:20]:
        print('FAIL', line, file=sys.stderr)
    sys.exit(1)
print(f'{files} files swept')
PY
); then
  pass "no crawlable email address in any text output ($sweep_out)"
else
  fail 'no crawlable email address in any text output'
fi

# 31. shortcode parameter whitelist: content may only use parameters the
#     theme actually reads. The set is derived from each shortcode's
#     implementation (.Get "key"), so adding a parameter to a template
#     automatically extends the contract — the whitelist cannot drift from
#     the code. Unknown parameters are accepted by Hugo and then silently
#     ignored, which is the failure mode docs/shortcodes.md guards.
if sc_out=$(python3 - "$ROOT" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])

def strip_comments(text):
    return re.sub(r'\{\{[-]?/\*.*?\*/[-]?\}\}', '', text, flags=re.S)

SUPPORTED = {}
for p in sorted((root / 'layouts/shortcodes').rglob('*.html')):
    name = p.relative_to(root / 'layouts/shortcodes').as_posix().removesuffix('.html')
    keys = {m.group(1) for m in re.finditer(r'\.Get\s+"([^"]+)"', strip_comments(p.read_text()))}
    SUPPORTED[name] = keys

bad = []
count = 0
pat = re.compile(r'\{\{[<%]\s*(/?)([a-zA-Z0-9/_-]+)([^>]*?)[>%]\}\}', re.S)
for md in sorted((root / 'test/fixture/content').rglob('*.md')):
    for m in pat.finditer(md.read_text()):
        closing, name, args = m.group(1), m.group(2), m.group(3)
        if closing or name not in SUPPORTED:
            if not closing:
                bad.append(f'{md.relative_to(root)}: unknown shortcode {name}')
            continue
        count += 1
        args = re.sub(r'"[^"]*"', '""', args)
        for key in re.findall(r'([A-Za-z][A-Za-z0-9]*)\s*=', args):
            if key not in SUPPORTED[name]:
                bad.append(f'{md.relative_to(root)}: {name} unsupported param {key}')
if bad:
    for line in bad:
        print('FAIL', line, file=sys.stderr)
    sys.exit(1)
print(f'{count} shortcode calls whitelisted, {len(SUPPORTED)} shortcodes scanned')
PY
); then
  pass "shortcode parameters stay inside the documented subset ($sc_out)"
else
  fail 'shortcode parameters stay inside the documented subset'
fi

# 32. rich footer: company, link columns, contact, social, switcher and
#     top button render from the [footer] table; the email is
#     entity-obfuscated and a missing social icon falls back to the name
assert 'index.html' 'site-footer__grid' 'footer grid renders'
assert 'index.html' 'Fixture Co\.' 'footer company name renders'
assert 'index.html' 'Quick Links' 'footer quick links title renders'
assert 'index.html' 'href="mailto:Case&#64;example\.net"' \
  'an upper-case MAILTO scheme normalises and entity-encodes'
assert 'index.html' 'info&#64;example\.net' 'footer email is entity-obfuscated'
assert 'index.html' 'Testville' 'footer address second line renders'
assert 'index.html' 'aria-label="Check"' 'footer social icon link renders'
assert 'index.html' 'aria-label="LinkedIn"[^>]*><svg' \
  'theme-shipped brand icon resolves from the module assets'
assert 'index.html' '>Fallback<' 'missing social icon falls back to the name'
assert 'index.html' 'site-footer__social" href="mailto:hello&#64;example\.net"' \
  'footer social mailto is entity-obfuscated'
assert 'index.html' 'site-header__toggle" data-appearance-toggle' 'switcher sits in the header'
assert_not 'index.html' 'data-appearance-toggle aria-pressed' \
  'three-state appearance toggle carries no boolean state'
assert 'index.html' 'class="back-to-top" data-scroll-top' 'scroll-to-top floats at the viewport corner'
assert 'index.html' 'aria-label="Back to top"' 'scroll-to-top is labelled'
assert 'index.html' 'site-footer__bottom' 'rich footer bottom travels as one bar'
assert 'index.html' 'href="/tags/"' 'footer menu entry links its page'
assert_not 'index.html' 'Categories<' 'unresolvable footer menu entry is dropped'
assert_not 'index.html' 'href="/categories/"' 'dropped footer menu entry ships no dead link'
assert_not 'index.html' 'site-footer__title' 'rich footer drops the duplicate identity block'

# 33. breadcrumbs: ancestors only. The current page is the H1 beside the trail,
#     so it is not repeated as a crumb. A crumb for a page that is in a menu
#     takes that menu's short label instead of the page title, while the schema
#     keeps the real title; a taxonomy ancestor with no menu entry falls back
#     to LinkTitle. Hidden when nothing sits above Home — a top-level section,
#     a taxonomy page or home is already announced by its menu entry and H1 —
#     and the page's own showBreadcrumbs still wins, either way.
assert 'section-a/flat/index.html' 'aria-label="Breadcrumb"' 'article trail renders'
assert 'section-a/flat/index.html' 'href="/"[^>]*>Home<' 'trail starts at Home'
assert 'section-a/flat/index.html' 'href="/section-a/"[^>]*>Section A<' 'crumb takes the menu label'
assert 'section-a/flat/index.html' '"name":"Feature Images, Formats and Optimization"' \
  'the schema keeps the section title'
assert 'tags/alpha/index.html' 'href="/tags/"[^>]*>Tags<' 'taxonomy crumb falls back to LinkTitle'
assert_not 'section-a/pixel/index.html' 'aria-label="Breadcrumb"' 'a page showBreadcrumbs false wins'
assert_not 'section-a/index.html' 'aria-label="Breadcrumb"' 'a top-level section has nothing above Home'
assert_not 'tags/index.html' 'aria-label="Breadcrumb"' 'a taxonomy page has nothing above Home'
assert_not 'index.html' 'aria-label="Breadcrumb"' 'home has nothing above Home'
# 33b. the trail is Home plus the ancestors and nothing else: no duplicate of
#      the section title or the page title, no current-page marker
if python3 - "$OUT" <<'PY'
import pathlib, re, sys
nav = pathlib.Path(sys.argv[1], 'section-a/flat/index.html').read_text()
m = re.search(r'<nav aria-label="Breadcrumb">.*?</nav>', nav, re.S)
assert m, 'no trail'
tray = m.group(0)
assert 'Feature Images, Formats and Optimization' not in tray, 'section title reached the trail'
assert 'Flat section image' not in tray, 'current page reached the trail'
assert 'breadcrumb__current' not in tray, 'current-page marker survived'
assert 'aria-current' not in tray, 'a crumb claims the current page'
assert re.findall(r'>([^<>]+)</a>', tray) == ['Home', 'Section A'], tray
PY
then
  pass 'trail is Home plus the ancestors, nothing repeated'
else
  fail 'trail is Home plus the ancestors, nothing repeated'
fi
# 33c. list and term headers share the article rhythm: the trail renders inside
#      .page-header ahead of the h1 (a trail outside the header once left
#      list pages 40px below the trail while articles sat 16px)
if python3 - "$OUT" <<'PY'
import pathlib, sys
for rel in ('section-a/nested/index.html', 'tags/alpha/index.html'):
    html = (pathlib.Path(sys.argv[1]) / rel).read_text()
    hi = html.find('<header class="page-header">')
    ni = html.find('<nav aria-label="Breadcrumb">')
    ti = html.find('<h1>')
    assert hi != -1 and ni != -1 and hi < ni < ti, rel
PY
then
  pass 'list trail sits inside the header ahead of the title'
else
  fail 'list trail sits inside the header ahead of the title'
fi
css_assert 'page-header\{margin-block:0 12px' 'list header carries no top gap of its own'
css_assert 'page-header:not\(:has\(.breadcrumb\)\)\{margin-top:40px' 'trail-less header keeps its top air'

# 33d. a section banner: gated by [list] showHero, mounted ahead of the
#      header on the shared hero block, preloaded like an article hero; a
#      section with no featureimage keeps the header rhythm instead
assert 'section-a/index.html' '<figure class="page-hero">' 'section banner renders'
assert 'section-a/index.html' 'class="page-hero__image"' 'section banner reuses the shared hero block'
assert 'section-a/index.html' 'alt="Section list hero"' 'section banner takes featureimagealt'
assert 'section-a/index.html' 'rel="preload"[^>]*imagesrcset="[^"]*"' 'section banner is preloaded'
assert_not 'section-a/nested/index.html' 'page-hero' 'a section with no featureimage shows no banner'
if python3 - "$OUT" <<'PY'
import pathlib, sys
html = (pathlib.Path(sys.argv[1]) / "section-a/index.html").read_text()
hi = html.find('<figure class="page-hero">')
head = html.find('<header class="page-header">')
ti = html.find('<h1>')
assert hi != -1 and head != -1 and ti != -1, 'banner, header or title missing'
assert hi < head < ti, 'the banner must come before the header and the title'
PY
then
  pass 'section banner sits ahead of the header'
else
  fail 'section banner sits ahead of the header'
fi

# 34. page front matter keys are read lowercase: Hugo folds content keys
#     (showBreadcrumbs arrives as showbreadcrumbs) while site config keeps
#     its case, so a camelCase .Params read on a page is silently dead
if grep -rn --include='*.html' -E '\.Params\.[A-Za-z]*[A-Z][A-Za-z]*' "$ROOT/layouts" | grep -v 'site\.Params' | grep -q .; then
  grep -rn --include='*.html' -E '\.Params\.[A-Za-z]*[A-Z][A-Za-z]*' "$ROOT/layouts" | grep -v 'site\.Params' >&2
  fail 'page .Params reads are lowercase only'
else
  pass 'page .Params reads are lowercase only'
fi
if grep -rn --include='*.html' -E 'isset \.Params "[a-z]*[A-Z]' "$ROOT/layouts" | grep -q .; then
  fail 'page isset keys are lowercase only'
else
  pass 'page isset keys are lowercase only'
fi

# 35. article author: page front matter wins, site [author] is the fallback,
#     both gated by showAuthor. An authorurl turns the byline into a link, but
#     without one it stays plain text — neither form invents a destination.
assert 'section-a/flat/index.html' 'By <a class="article__author"[^>]*>Flat Author</a>' \
  'a page author with a url renders as a link'
assert 'section-a/nested/post/index.html' 'By Fixture Team' 'site author is the fallback'

# 36. carousel loop is seamless: a hidden clone of the first slide closes
#     the track so last-to-first animates instead of jumping. Real slides are
#     the ones carrying role="group"; the clone carries only aria-hidden.
count_assert 'section-a/shortcodes/index.html' 'aria-roledescription="slide"' 3 \
  'carousels keep three real slides'
assert 'section-a/shortcodes/index.html' 'aria-hidden="true" tabindex="-1"' \
  'carousel appends a hidden first-slide clone'

# 37. article-vs-page width: sections in mainSections stay prose-capped,
#     standalone pages render full width
assert 'notice/index.html' 'class="page--wide"' 'non-article single goes full width'
assert_not 'section-a/flat/index.html' 'page--wide' 'article single stays capped'
assert 'index.html' 'class="page-content prose page--wide"' 'home content uses the wide landing measure'
css_assert 'page--wide\.prose\{max-width:none' 'landing page lifts the measure off the container'
css_assert_not 'page--wide\.prose>p\{max-width' \
  'landing paragraphs ride the wide measure, no separate cap'
# 44. list and single pages share one top rhythm: the article header
#     carries no top margin of its own (hero images keep their own spacing)
css_assert_not 'article__header\{[^}]*margin-top' 'the article header carries no top margin of its own'
css_assert 'article__header\{[^}]*max-width:var\(--prose-measure,720px\);margin-inline:auto' \
  'the article header rides the reading measure with the body'
# 45. mobile disclosure menu: hamburger with synced state, nested
#     submenu behind a chevron button, loader wired
assert 'index.html' 'data-nav-toggle aria-expanded="false"' 'hamburger starts collapsed'
assert 'index.html' 'data-nav-subtoggle' 'parent gets a submenu chevron'
assert 'index.html' 'href="/section-a/flat/"' 'nested entry links its page'
assert 'index.html' 'menu\.[0-9a-f]+\.js' 'menu script loads'
assert 'index.html' 'aria-controls="site-navigation"' 'hamburger names its panel'
assert 'index.html' 'id="site-navigation" data-nav-panel' 'panel carries the named id'
assert 'index.html' 'class="site-nav__sub" id="nav-sub-[0-9]*" hidden' 'submenu starts hidden'
css_assert 'site-header\{position:relative' 'standard header anchors the mobile panel'
css_assert_not 'site-header\{[^}]*border-bottom' 'header bar is ruled by its opaque background, not a hairline'
css_assert 'site-header\{[^}]*padding-block:6px' 'header padding agrees with the 92px bar'
css_assert 'site-nav__link\{[^}]*font-size:16px' 'nav links carry the 16px size'
css_assert 'site-nav__link\{[^}]*font-weight:600' 'nav links carry the weight that makes them read at 16px'
css_assert 'site-nav\{margin-inline-start:auto' 'nav and action buttons sit as one group at the right'
assert 'index.html' 'class="site-nav" id="site-navigation"' \
  'the nav carries the class that right-align rule targets'
css_assert 'max-width:852px\)\{\.site-nav__toggle\{display:inline-flex;margin-inline-start:auto' \
  'mobile: the hidden nav gives its auto margin to the hamburger'
css_assert 'site-header\{[^}]*gap:12px' 'header items are tight once the nav is pushed right'
css_assert '\-\-brand-logo-height:80px' 'logo height is a token a site can override'
css_assert 'site-brand__logo\{[^}]*height:var\(--brand-logo-height\)' 'logo size reads the token'
css_assert 'site-header__toggle\{[^}]*width:44px' 'appearance toggle is a square target, not a padded box'
css_assert 'site-header__toggle\{[^}]*border:0' 'appearance toggle carries no box, hover is colour only'
css_assert 'site-header__search\{[^}]*border:0' 'search toggle carries no box, hover is colour only'
css_assert 'site-nav__toggle\{[^}]*border:0' 'hamburger carries no box'
assert 'index.html' 'site-search__icon" aria-hidden="true"><svg' 'search toggle ships the search glyph'
assert 'index.html' 'site-nav__bars" aria-hidden="true"><svg' 'hamburger ships the bars glyph'
css_assert 'site-nav__link\[aria-current=page\]\{[^}]*font-weight:700' 'active nav item has a non-color cue'
css_assert 'site-footer__link\{[^}]*min-height:28px' 'footer links keep a 28px target'
css_assert 'site-footer__heading\{font-size:16px' 'footer column headings carry the 16px size'
css_assert 'site-header__toggle__icon\{[^}]*width:18px' 'appearance glyphs render at 18px'
assert 'index.html' 'site-header__toggle__icon--moon' 'appearance toggle ships both scheme glyphs'
# The moon-hide rule must come AFTER the shared icon box rule. Both carry one
# class of specificity, so source order decides — reversed, both glyphs render
# at once. This is a cascade-order property, so grep for the offsets.
if cssfile=$(ls "$OUT"/css/theme*.css 2>/dev/null | head -1) &&
   [ -n "$cssfile" ] &&
   base_off=$(grep -bo 'site-header__toggle__icon{display:inline-flex' "$cssfile" | cut -d: -f1) &&
   moon_off=$(grep -bo 'site-header__toggle__icon--moon{display:none' "$cssfile" | cut -d: -f1) &&
   [ "$base_off" -lt "$moon_off" ]; then
  pass 'moon glyph hides after the shared icon box rule'
else
  fail 'moon glyph hides after the shared icon box rule'
fi
css_assert 'site-footer__link\[aria-current=page\]\{[^}]*font-weight:600' 'active footer item has a non-color cue'
css_assert 'carousel__frame--contain img\{[^}]*object-fit:contain' \
  'contain fit overrides cover for a slide frame'
css_assert 'carousel__indicators\{[^}]*position:absolute' 'carousel dots overlay the image'
css_assert 'carousel__indicators\{[^}]*bottom:10px' 'carousel dots sit at the image bottom'
css_assert 'carousel__indicators button\{[^}]*width:32px' 'carousel dots are bars, not circles'
css_assert 'carousel__indicators button::before\{[^}]*inset:-10px -6px' \
  'carousel dot hit area stays at 44x25 behind a 5px bar'
css_assert 'carousel:has\(\.carousel__caption\)[^}]*\.carousel__indicators\{top:10px' \
  'captioned carousel moves the dots above the caption'
css_assert 'card--row:has\(> *\.card__media\)[^{}]*\{[^}]*240px 1fr' \
  'row card splits into two columns only when it has media'
css_assert 'card--row:has\(> *\.card__media\) \.card__media[^{}]*\{[^}]*min-height:0' \
  'row thumb height comes from the 16:9 aspect, not the source image'
css_assert 'card--row:has\(> *\.card__media\) \.card__summary[^{}]*\{[^}]*grid-column:2' \
  'row summary sits beside the thumb, not over it'
css_assert_not 'min-height:112px' 'no residual row thumb minimum height'
css_assert 'site-footer__meta\{[^}]*margin-inline-start:auto' \
  'footer social group sits at the right of the bottom bar'
css_assert 'site-footer__social\{[^}]*background:var\(--surface\)' 'footer social is a filled tile'
css_assert 'site-footer__social:has\(svg\)\{[^}]*width:44px' 'footer social icon fills the tile'
css_assert 'site-footer__social svg\{[^}]*width:22px' 'footer social glyphs are large enough to read'
# 45b. the 853px breakpoint is written twice (CSS collapse, JS reset):
#     drift once and the panel sticks open on desktop or never opens
if grep -q 'min-width: 853px' "$ROOT/assets/js/menu.js" &&
   grep -q 'max-width: 852px' "$ROOT/assets/css/components/site.css" &&
   grep -q 'min-width: 853px' "$ROOT/assets/css/components/site.css"; then
  pass 'menu breakpoint 853px agrees across CSS and JS'
else
  fail 'menu breakpoint 853px agrees across CSS and JS'
fi
 # 45c. Escape handling is behaviour, not markup: assert the source path
 #     (same pattern as #43 — markup cannot show it). The handler now lives
 #     in the shared dropdown contract; the menu is one of its registrants.
if grep -q 'strataRegisterDropdown(btn, panel' "$ROOT/assets/js/menu.js" &&
   grep -q '"Escape"' "$ROOT/assets/js/dropdowns.js" &&
   grep -q 'toggle.focus()' "$ROOT/assets/js/dropdowns.js"; then
  pass 'menu closes on Escape with focus back on the button'
else
  fail 'menu closes on Escape with focus back on the button'
fi
# 45d. the panel cap is measured, not assumed: a wrapped header would
#      otherwise push a tall panel past the viewport (same pattern)
if grep -q 'panel\.style\.maxHeight' "$ROOT/assets/js/menu.js" &&
   grep -q 'getBoundingClientRect().top' "$ROOT/assets/js/menu.js"; then
  pass 'menu caps the panel from the live header bottom'
else
  fail 'menu caps the panel from the live header bottom'
fi
# 46. search: header button plus dropdown panel, JSON index of articles
#     only, slim entries, behaviour asserted at the source (#43 pattern)
assert 'index.html' 'data-search-toggle aria-expanded="false"' 'search button starts collapsed'
assert 'index.html' 'aria-controls="site-search"' 'search button names its panel'
assert 'index.html' 'id="site-search" data-search-panel' 'search panel carries the named id'
assert 'index.html' 'data-search-index="[^"]*index\.json"' 'panel points at the index'
assert 'index.html' 'search\.[0-9a-f]+\.js' 'search script loads'
if python3 - "$OUT" <<'PY'
import json, pathlib, sys
entries = json.loads((pathlib.Path(sys.argv[1]) / 'index.json').read_text())
assert isinstance(entries, list) and entries, 'empty index'
for e in entries:
    assert set(e) == {'title', 'url', 'date', 'summary', 'content'}, e.keys()
    assert e['title'] and e['url'], 'blank title or url'
    assert len(e['content']) <= 600, 'search.contentLength override ignored'
    assert e['url'].startswith('/section-a/'), 'non-article leaked in'
PY
then
  pass 'search index holds slim article entries only'
else
  fail 'search index holds slim article entries only'
fi
if grep -q '3 \* inTitle + 2 \* inSummary + inContent' "$ROOT/assets/js/search.js" &&
   grep -q 'strataRegisterDropdown(btn, panel' "$ROOT/assets/js/search.js" &&
   grep -q '"Escape"' "$ROOT/assets/js/dropdowns.js" &&
   grep -q 'list.addEventListener("click"' "$ROOT/assets/js/search.js"; then
  pass 'search scores, escapes and shares the panel contract'
else
  fail 'search scores, escapes and shares the panel contract'
fi
css_assert 'article__header h1,.page-header h1\{font-size:2.125rem' 'page titles share one size rule'
# 47. a11y panel: disclosure plus three persisted switches; the motion
#     switch is read live by scroll-to-top and the carousel (#43 pattern)
assert 'index.html' 'data-a11y-toggle aria-expanded="false"' 'a11y button starts collapsed'
assert 'index.html' 'aria-controls="site-a11y"' 'a11y button names its panel'
assert 'index.html' 'id="site-a11y" data-a11y-panel' 'a11y panel carries the named id'
count_assert 'index.html' 'data-a11y-setting="[^"]*"' 3 'three switches render'
assert 'index.html' 'a11y\.[0-9a-f]+\.js' 'a11y script loads'
if grep -q 'a11y-reduce-motion' "$ROOT/assets/js/scroll-top.js" &&
   grep -q 'a11y-reduce-motion' "$ROOT/assets/js/carousel.js" &&
   grep -q 'if (calm())' "$ROOT/assets/js/carousel.js"; then
  pass 'motion switch is read live by scroll-to-top and the carousel'
else
  fail 'motion switch is read live by scroll-to-top and the carousel'
fi
css_assert 'html\.a11y-underline-links a\{text-decoration:underline' 'underline-links class applies'
css_assert 'html\.a11y-strong-focus :focus-visible\{outline-width:4px' 'strong-focus class applies'
 # the three dropdowns share one contract: each opener registers with
 # assets/js/dropdowns.js, which owns mutual exclusion, aria-expanded and
 # Escape. Symmetric by construction — dropping the helper from any opener
 # fails here, and a fourth dropdown is one registration.
if grep -q 'strataRegisterDropdown' "$ROOT/assets/js/dropdowns.js" &&
   grep -q '"Escape"' "$ROOT/assets/js/dropdowns.js" &&
   grep -q 'strataRegisterDropdown' "$ROOT/assets/js/menu.js" &&
   grep -q 'strataRegisterDropdown' "$ROOT/assets/js/search.js" &&
   grep -q 'strataRegisterDropdown' "$ROOT/assets/js/a11y.js" &&
   grep -q 'dropdowns\.[0-9a-f]*\.js' "$OUT/index.html"; then
  pass 'dropdowns share one mutual-exclusion contract'
else
  fail 'dropdowns share one mutual-exclusion contract'
fi
 # 47b. stored classes must land in the head before the first paint: the
 #      head copy applies them ahead of the DOMContentLoaded wiring, and
 #      the panel partial ships no script of its own
if grep -q 'applyClasses();' "$ROOT/assets/js/a11y.js" &&
   grep -q 'DOMContentLoaded' "$ROOT/assets/js/a11y.js" &&
   grep -q 'a11y.Data.Integrity }}"></script>' "$ROOT/layouts/partials/head/head.html" &&
   ! grep -q '<script' "$ROOT/layouts/partials/frame/a11y.html"; then
  pass 'a11y classes apply in the head before first paint'
else
  fail 'a11y classes apply in the head before first paint'
fi
 # 47c. the motion switch is a live no-op for users whose OS already
 #      reduces motion — both rules only turn motion off — so it is
 #      disabled and labelled instead of pretending to work
if grep -q 'prefers-reduced-motion' "$ROOT/assets/js/a11y.js" &&
   grep -q 'motionBox.disabled = true' "$ROOT/assets/js/a11y.js" &&
   grep -q 'box.disabled' "$ROOT/assets/js/a11y.js" &&
   grep -q 'data-a11y-os-note' "$ROOT/layouts/partials/frame/a11y.html"; then
  pass 'motion switch is disabled, not faked, when the OS reduces motion'
else
  fail 'motion switch is disabled, not faked, when the OS reduces motion'
fi
 css_assert 'html\.a11y-underline-links a\{text-decoration:underline;text-decoration-thickness:2px' 'underline links carry a visible weight'
 css_assert '\.site-search__results\{list-style:none;padding-block:6px' 'focus ring is not clipped at the results list top'
 # 48. no font-size switch: the theme mixes rem and px, so a root bump
 #     scales only half the type — browser zoom is the honest tool
 if grep -q 'No font-size switch on purpose' "$ROOT/layouts/partials/frame/a11y.html" &&
    grep -q 'No font-size switch on purpose' "$ROOT/exampleSite/content/docs/configuration.md"; then
  pass 'the deliberate font-size omission is documented at the point of use'
else
  fail 'the deliberate font-size omission is documented at the point of use'
fi
# 33c. the home title left the naked-h1 era: it renders inside .page-header
#      like every other page title (same size, same top air)
if python3 - "$OUT" <<'PY'
import pathlib, sys
html = (pathlib.Path(sys.argv[1]) / 'index.html').read_text()
hi = html.find('<header class="page-header">')
ti = html.find('<h1>', hi)
ci = html.find('</header>', hi)
assert hi != -1 and hi < ti < ci, 'home h1 outside the header'
PY
then
  pass 'home title sits inside the page header'
else
  fail 'home title sits inside the page header'
fi

# 38. smart header: sticks, hides on scroll down (script present and wired)
assert 'index.html' 'site-header--smart" data-smart-header' 'smart shell renders'
assert 'index.html' 'smart-header\.[0-9a-f]+\.js' 'smart script loads'
# 38b. the sticky bar must clear in-page anchor jumps, or a heading lands
#      under it. Gated on :has, so a static header (which scrolls away) gets
#      no offset and no empty band at the top of the viewport. --header-bar
#      lives on html for the same reason: a scroll container cannot read a
#      property defined on the element it is offsetting.
css_assert 'html\{--header-bar:' \
  'the header height is a root token the scroll container can read'
css_assert 'html:has\(\.site-header--smart\)\{scroll-padding-top:var\(--header-bar\)' \
  'anchors land below the sticky header, not under it'
# 43. hidden chrome leaves the focus order: the smart header toggles inert
#     with its transform (a behaviour assert, since markup cannot show it)
if grep -q 'header\.inert *= *true' "$ROOT/assets/js/smart-header.js" &&
   grep -q 'header\.inert *= *false' "$ROOT/assets/js/smart-header.js"; then
  pass 'smart header toggles inert with visibility'
else
  fail 'smart header toggles inert with visibility'
fi
# 43b. smart init is behaviour too: a reload already scrolled down must
#      start hidden (this exact init once shipped as a no-op the old
#      gate could not see — same pattern as #43)
if grep -q 'window\.scrollY >= 100' "$ROOT/assets/js/smart-header.js" &&
   grep -q 'header\.inert *= *true' "$ROOT/assets/js/smart-header.js"; then
  pass 'smart header hides on load when already scrolled'
else
  fail 'smart header hides on load when already scrolled'
fi

# 39. scheme contrast: every colour scheme must declare its full anchor set, and
#     the palette resolved from those anchors must stay readable in both modes.
#     The decorative colours palette.css derives with color-mix are evaluated
#     here rather than skipped, so a bad anchor cannot hide behind a derived
#     surface. Floors: copy-bearing tokens (text, link, ok, error) at 4.5:1 on
#     the ground, faint text and the 2px focus ring at 3:1, white on the accent
#     fills at 4.5:1 because cta.css and contact-form.css hard-code white labels,
#     and the selection pair at 4.5:1. palette.css carries no literal colour
#     fallbacks, so the missing-anchor check is the safety net.
if contrast_out=$(python3 - "$ROOT" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])

def lum(h):
    h = h.lstrip('#')
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]

def ratio(a, b):
    hi, lo = sorted([lum(a), lum(b)], reverse=True)
    return (hi + 0.05) / (lo + 0.05)

def mix(a, b, f):
    """color-mix(in srgb, a f%, b), computed the way the browser does."""
    pa = [int(a.lstrip('#')[i:i + 2], 16) for i in (0, 2, 4)]
    pb = [int(b.lstrip('#')[i:i + 2], 16) for i in (0, 2, 4)]
    return '#%02x%02x%02x' % tuple(round(x * f + y * (1 - f)) for x, y in zip(pa, pb))

MIX = re.compile(r'^color-mix\(in srgb,\s*(#[0-9a-fA-F]{6})\s+([\d.]+)%\s*,\s*(#[0-9a-fA-F]{6})\s*\)$')
VAR_FB = re.compile(r'var\((--[\w-]+)\s*,\s*([^)]+)\)')
VAR_PLAIN = re.compile(r'var\((--[\w-]+)\)')

def block_vars(text, selector):
    m = re.search(re.escape(selector) + r'\s*\{([^}]*)\}', text)
    return re.findall(r'(--[\w-]+)\s*:\s*([^;]+);', m.group(1)) if m else []

def resolve(decls, scheme):
    """Evaluate palette declarations in source order over a scheme's anchors."""
    out = {}
    def look(key):
        for pool in (out, scheme):
            if key in pool:
                return pool[key]
        raise KeyError(key)
    for name, expr in decls:
        v = expr.strip()
        m = VAR_FB.search(v)
        if m:
            try:
                v = look(m.group(1))
            except KeyError:
                v = v.replace(m.group(0), m.group(2).strip())
        v = VAR_PLAIN.sub(lambda mm: look(mm.group(1)), v)
        m = MIX.match(v)
        out[name] = mix(m.group(1), m.group(3), float(m.group(2)) / 100) if m else v
    return out

REQUIRED = ('--site-page-bg', '--site-text', '--site-text-muted',
            '--site-text-faint', '--site-text-strong', '--site-accent',
            '--site-accent-strong', '--site-link', '--site-ring',
            '--site-ok', '--site-error')
ON_BG = (('--text', 4.5), ('--text-muted', 4.5), ('--text-faint', 3.0),
         ('--site-text-strong', 4.5), ('--site-link', 4.5), ('--accent-fg', 4.5),
         ('--site-ring', 3.0), ('--site-ok', 4.5), ('--site-error', 4.5))
ON_OTHER = (('--accent-fg', '--surface-tint', 3.0),
            ('--site-text-strong', '--accent-soft', 4.5))
WHITE_ON = ('--site-accent', '--site-accent-strong')

pal = (root / 'assets/css/base/palette.css').read_text()
bad, pairs = [], 0
def check(scope, fg, bg, floor):
    global pairs
    r = ratio(scope[fg], scope[bg])
    pairs += 1
    if r < floor:
        bad.append(f'{scope["name"]} {scope["mode"]} {fg} on {bg} '
                   f'{scope[fg]} = {r:.2f} < {floor}')

for p in sorted((root / 'assets/css/schemes').glob('*.css')):
    css = p.read_text()
    for mode in (':root', ':root.dark'):
        anchors = dict(block_vars(css, mode))
        need = REQUIRED + (('--site-accent-fg',) if mode == ':root.dark' else ())
        missing = [k for k in need if k not in anchors]
        if missing:
            bad.append(f'{p.name} {mode} missing anchors: {", ".join(missing)}')
            continue
        scope = {'name': p.name, 'mode': mode}
        scope.update(anchors)
        scope.update(resolve(block_vars(pal, mode), anchors))
        for fg, floor in ON_BG:
            check(scope, fg, '--page-bg', floor)
        for fg, ob, floor in ON_OTHER:
            check(scope, fg, ob, floor)
        for fg in WHITE_ON:
            r = ratio('#ffffff', scope[fg])
            pairs += 1
            if r < 4.5:
                bad.append(f'{p.name} {mode} white on {fg} {scope[fg]} = {r:.2f} < 4.5')
if bad:
    for b in bad:
        print(f'FAIL {b}')
    sys.exit(1)
print(f'all {pairs} contrast pairs clear their floor in every scheme and mode')
PY
); then
  pass "scheme contrast holds ($contrast_out)"
else
  printf '%s\n' "$contrast_out" >&2
  fail 'every scheme declares its anchors and holds contrast'
fi

# 40. keyboard and assistive-tech paths: skip link, carousel arrows and
#     reduced-motion guards, contact live region and invalid flag
assert 'index.html' 'class="skip-link" href="#main-content"' 'skip link targets the main block'
assert 'index.html' '<main id="main-content" tabindex="-1">' 'skip link lands on a focusable main'
assert_at "$ROOT/assets/js" 'carousel.js' 'ArrowLeft|ArrowRight' \
  'carousel handles arrow keys'
assert_at "$ROOT/assets/js" 'carousel.js' 'prefers-reduced-motion' \
  'carousel honours reduced motion'
assert 'section-a/shortcodes/index.html' 'role="status"' 'contact status is a live region'
assert 'section-a/shortcodes/index.html' 'aria-describedby=' 'message field names its limit'
assert 'section-a/shortcodes/index.html' 'aria-invalid=' 'message field exposes validity'

# 41. ads ship complete and consent has a home: the unit carries client
#     and slot, the loader lands only on pages using it, and the
#     site-owned consent partial renders through the baseof hook
assert 'section-a/shortcodes/index.html' 'data-ad-client="ca-pub-0000000000000000"' 'ads unit carries the client'
assert 'section-a/shortcodes/index.html' 'data-ad-slot="1234567890"' 'ads unit carries the slot'
assert 'section-a/shortcodes/index.html' 'adsbygoogle\.js\?client=' 'ads loader loads on unit pages'
assert_not 'section-a/flat/index.html' 'adsbygoogle' 'ads loader stays off unit-less pages'
assert 'section-a/shortcodes/index.html' 'src="?/js/ads\.[0-9a-f]+\.js"? integrity="sha512-' \
  'ad push ships as an external fingerprinted script'
assert_not 'section-a/shortcodes/index.html' '\(adsbygoogle = window' 'ad push is never an inline script'
assert '_headers' 'script-src[^;]*pagead2\.googlesyndication\.com' \
  'the site headers allow the ad loader'
assert 'index.html' 'data-cookie-consent' 'consent hook renders site markup'

# 42. verifiable authorship and trail metadata: Person author and
#     BreadcrumbList in JSON-LD, article tags/section and twitter:site in
#     meta, Organization published once with an @id others reference
assert 'section-a/flat/index.html' '"@type":"Person"' 'schema carries a Person author'
assert 'section-a/flat/index.html' '"name":"Flat Author"' 'author name matches the byline'
assert 'section-a/flat/index.html' 'author\.example\.net' 'author links travel as sameAs'
assert 'section-a/flat/index.html' '"@type":"BreadcrumbList"' 'schema carries the trail'
assert 'section-a/flat/index.html' 'article:tag' 'article tags are emitted'
assert 'section-a/flat/index.html' 'article:section' 'article section is emitted'
assert 'section-a/flat/index.html' 'twitter:site' 'twitter:site is emitted'
assert 'section-a/flat/index.html' 'name="twitter:creator" content="@fixturecreator"' \
  'twitter:creator is emitted from the site param'
assert 'index.html' '"@type":"Organization"' 'schema carries the publisher once'
assert_not 'index.html' '(?i)<script[^>]*application/ld\+json[^>]*>[^<]*mailto:' \
  'Organization sameAs drops mailto entries'
assert_not 'section-a/flat/index.html' '(?i)<script[^>]*application/ld\+json[^>]*>[^<]*mailto:' \
  'Person sameAs drops mailto entries'
assert_not 'section-a/links/index.html' '(?i)<script[^>]*application/ld\+json[^>]*>[^<]*mailto:' \
  'schema never renders a mailto person url'
assert 'section-a/anim/index.html' 'name="description" content="Animated WebP feature image"' \
  'meta description strips markup from the front matter value'
assert_not 'section-a/anim/index.html' 'name="description" content="[^"]*&lt;' \
  'no escaped markup leaks into the meta description'
assert 'section-a/anim/index.html' 'property="og:description" content="Animated WebP feature image"' \
  'og:description carries the same stripped text as the meta tag'
assert 'section-a/anim/index.html' 'name="twitter:description" content="Animated WebP feature image"' \
  'twitter:description carries the same stripped text as the meta tag'
assert 'section-a/inline/index.html' 'property="og:description" content="Inline illustration summary"' \
  'og:description falls back to the summary when no description is set'
assert_not 'section-a/anim/index.html' 'property="og:description" content="[^"]*&lt;' \
  'no escaped markup leaks into og:description'
assert 'section-a/pixel/index.html' 'name="description" content="A Hugo theme for content sites\."' \
  'a page with neither key falls back to the site description'
assert 'section-a/pixel/index.html' 'property="og:description" content="A Hugo theme for content sites\."' \
  'og:description takes the same site description'
# Last resort, past the site description: the page title must win, not the bare
# site title. Needs its own build because the theme ships a site description
# that the fixture inherits, so no fixture page reaches this on its own. The
# config/nodesc/ overlay clears the key at the language level — Hugo dropped
# HUGO_PARAMS_* env-var overrides after 0.151, and the theme sets the key in
# its own languages.en.toml, which a site-level [params] cannot shadow.
hugo --source "$ROOT/test/fixture" --environment nodesc \
  --destination "$OUT_NOSITEDESC" --quiet
if grep -qE 'name="description" content="GIF pixel — Strata Fixture"' \
    "$OUT_NOSITEDESC/section-a/pixel/index.html" 2>/dev/null; then
  pass 'clearing the site description falls back to the page title'
else
  fail 'clearing the site description falls back to the page title'
fi
if grep -qE 'property="og:description" content="GIF pixel — Strata Fixture"' \
    "$OUT_NOSITEDESC/section-a/pixel/index.html" 2>/dev/null; then
  pass 'og:description falls back to the page title as well'
else
  fail 'og:description falls back to the page title as well'
fi

# 42c. robots defaults to indexing with the large image preview, a page value
#      overrides it, and a site value applies only where a page is silent. The
#      last two need the config/robots/ overlay, which is where the theme can
#      not ship a site-level value.
assert 'section-a/flat/index.html' \
  'name="robots" content="index, follow, max-image-preview:large"' \
  'robots defaults to indexing with the large image preview'
assert 'notice/index.html' 'name="robots" content="index, follow, noarchive"' \
  'a page-level robots value overrides the default'
hugo --source "$ROOT/test/fixture" --environment robots \
  --destination "$OUT_ROBOTS" --quiet
assert_at "$OUT_ROBOTS" 'section-a/flat/index.html' 'name="robots" content="noindex, nofollow"' \
  'a site-level robots value applies where a page declares none'
assert_at "$OUT_ROBOTS" 'notice/index.html' 'name="robots" content="index, follow, noarchive"' \
  'a page-level robots value beats the site value'

# The rendered robots.txt opens the crawl only in a production build and
# declares the sitemap. hugo.IsProduction is false under `hugo server`, which
# is what keeps a local dev server out of the index; that branch is pinned in
# the template, since a build can only ever prove the production one.
assert_at "$OUT" 'robots.txt' '^Allow: /$' \
  'robots.txt allows the crawl in a production build'
assert_at "$OUT" 'robots.txt' '^Sitemap: https://example\.org/sitemap\.xml$' \
  'robots.txt declares the sitemap'
if grep -q 'Disallow: /' "$ROOT/layouts/robots.txt" \
  && grep -q 'hugo.IsProduction' "$ROOT/layouts/robots.txt"; then
  pass 'robots.txt keeps a dev server out of the index'
else
  fail 'robots.txt keeps a dev server out of the index'
fi

# 42b. Article description and keywords mirror the front matter, including its
#      two fallbacks (summary -> description, tags -> keywords) and the "neither
#      source" case where neither key may be invented. All four combinations are
#      pinned so deleting one side of an `or` fails here. The anim keywords are
#      trimmed, deduplicated and blank-stripped, which pins data/keywords.html's
#      normalisation on the JSON-LD side. Parsed from the ld+json payload, not
#      grepped — "description" also appears on the meta tag line, which would
#      make a grep negative match the wrong node
if schema_out=$(python3 - "$OUT" <<'PY'
import json
import re
import sys
from pathlib import Path

out = Path(sys.argv[1])
failed = []
expect = {
    "section-a/anim": {"description": "Animated WebP feature image",
                       "keywords": ["WebP", "animation", "animated image"]},
    "section-a/inline": {"description": "Inline illustration summary",
                         "keywords": None},
    "section-a/flat": {"description": None,
                       "keywords": ["alpha", "beta", "Sci & Tech"]},
    "section-a/pixel": {"description": None, "keywords": None},
}
for rel, want in expect.items():
    text = (out / rel / "index.html").read_text(encoding='utf-8')
    m = re.search(r'<script type="application/ld\+json">(.*?)</script>', text, re.S)
    if not m:
        failed.append("%s renders no JSON-LD" % rel)
        continue
    nodes = json.loads(m.group(1))
    nodes = nodes.get("@graph", nodes) if isinstance(nodes, dict) else nodes
    art = [n for n in nodes if n.get("@type") == "Article"]
    if len(art) != 1:
        failed.append("%s renders %d Article nodes" % (rel, len(art)))
        continue
    a = art[0]
    for key, wanted in want.items():
        got = a.get(key)
        if wanted is None:
            if key in a:
                failed.append("%s %s is %r though no front matter source sets it"
                              % (rel, key, got))
        elif got != wanted:
            failed.append("%s %s is %r, want %r" % (rel, key, got, wanted))
if failed:
    for line in failed:
        print("FAIL " + line, file=sys.stderr)
    sys.exit(1)
print("description and keywords mirror the front matter and its two fallbacks")
PY
); then
  pass "article schema description and keywords ($schema_out)"
else
  fail 'article schema description and keywords'
fi

# 42c. The meta keywords tag comes from the same data/keywords.html partial the
#      JSON-LD reads, so one resolver feeds both. Items are deduplicated and
#      whitespace-trimmed, the tag is omitted when no item survives, and a
#      page carrying neither keywords nor tags may not get one invented. The
#      tags form written as a bare string must split on commas instead of
#      iterating runes, which the fixture's all-array tags cannot reach on its
#      own, so it builds the draft strtags page the same way validate-theme
#      builds missing.md
assert 'section-a/anim/index.html' 'name="keywords" content="WebP, animation, animated image"' \
  'meta keywords trims, deduplicates and drops blanks'
assert 'section-a/flat/index.html' 'name="keywords" content="alpha, beta, Sci &amp; Tech"' \
  'meta keywords falls back to tags and escapes markup'
assert_not 'section-a/pixel/index.html' 'name="keywords"' \
  'a page with neither key gets no keywords tag'
if grep -rlE '%!s\(' "$OUT" --include='*.html' >/dev/null 2>&1; then
  fail 'no format artefact leaks into the rendered output'
else
  pass 'no format artefact leaks into the rendered output'
fi
# The drafts build exits non-zero on the draft missing.md's unresolvable
# featureimage, which validate-theme asserts; strtags.md is written before the
# build stops, so the assertions below still have a page to read
hugo --source "$ROOT/test/fixture" --buildDrafts --destination "$OUT_DRAFTS" \
  --quiet 2>"$WORK/drafts.stderr" || true
assert_at "$OUT_DRAFTS" 'section-a/strtags/index.html' 'name="keywords" content="bare, string"' \
  'tags written as a bare string split on commas'
assert_at "$OUT_DRAFTS" 'section-a/strtags/index.html' '"keywords":\["bare","string"\]' \
  'a bare string tags value yields exactly two items'

# 42d. Series is its own graph node with its members in the same weight order
#      as the page/series.html navigation, and the Article points back at it.
#      Positions and ids are pinned, so a reorder or an id drift shows up here
#      instead of in a search engine's crawl.
if series_out=$(python3 - "$OUT" <<'PY'
import json
import re
import sys
from pathlib import Path

out = Path(sys.argv[1])
failed = []
for rel in ("section-a/series-a", "section-a/series-b"):
    text = (out / rel / "index.html").read_text(encoding="utf-8")
    m = re.search(r'<script type="application/ld\+json">(.*?)</script>', text, re.S)
    if not m:
        failed.append("%s renders no JSON-LD" % rel)
        continue
    nodes = json.loads(m.group(1))
    nodes = nodes.get("@graph", nodes) if isinstance(nodes, dict) else nodes
    series = [n for n in nodes if n.get("@type") == "Series"]
    if len(series) != 1:
        failed.append("%s renders %d Series nodes" % (rel, len(series)))
        continue
    s = series[0]
    if s.get("name") != "Smoke Series":
        failed.append("%s Series name is %r" % (rel, s.get("name")))
    parts = s.get("hasPart") or []
    positions = [p.get("position") for p in parts]
    if positions != [1, 2]:
        failed.append("%s hasPart positions are %r, want [1, 2]" % (rel, positions))
    if any(not str(p.get("@id", "")).endswith("#article") for p in parts):
        failed.append("%s has a non-article hasPart id: %r" % (rel, parts))
    art = [n for n in nodes if n.get("@type") == "Article"]
    if len(art) != 1:
        failed.append("%s renders %d Article nodes" % (rel, len(art)))
        continue
    got = art[0].get("isPartOfSeries")
    if got != {"@id": s.get("@id")}:
        failed.append("%s isPartOfSeries is %r, want the Series node id" % (rel, got))
if failed:
    for line in failed:
        print("FAIL " + line, file=sys.stderr)
    sys.exit(1)
print("series nodes carry their members and the article points back")
PY
); then
  pass "series schema ($series_out)"
else
  fail 'series schema'
fi

# 48. article chrome: the hero crops to its configured height instead of
#     letterboxing, the body keeps the reading measure, related content reuses the
#     card grid with lazy images, sharing links are centred icon tiles, and
#     adjacent articles sit under their own rule. One anchor per sharingLinks
#     name from data/sharing.json, title urlquery-encoded, opener opted out
#     except mailto. Also the meta separator: the · belongs between adjacent
#     items, not to the date, so a page with no date must still separate two
#     tags rather than glue them
css_assert 'page-hero\{[^}]*margin-block:32px' 'the hero block keeps its own air'
css_assert 'page-hero__image\{[^}]*height:var\(--page-hero-height\);object-fit:cover' 'the hero crops to its configured height'
css_assert 'page-hero\+\.page-header\{margin-top:0' 'a trail-less header adds no air after a hero'
css_assert 'page-content\{[^}]*max-width:none' 'landing page copy rides the full column'
css_assert_not 'article__content\.prose\{max-width:none' 'the article body keeps the reading measure'
css_assert 'article\.page--wide>\.article__header' \
  'a landing page lifts the title block with the body'
css_assert 'series\{[^}]*max-width:var\(--prose-measure,720px\)' \
  'the series box tracks the reading measure'
css_assert 'article__related\{margin-block:0;padding-top:28px' 'related block gets its own rhythm'
css_assert_not 'article__related\{[^}]*border-top' 'related sits apart by space, not a rule'
css_assert 'article__share\{display:flex;flex-wrap:wrap;justify-content:center' 'share tiles centre on the column'
css_assert 'article__share-link\{[^}]*min-height:44px' 'share links keep a 44px target'
css_assert 'article__share-link\{[^}]*border-radius:8px' 'share tiles share the footer radius'
css_assert 'article__share-link:has\(svg\)\{[^}]*width:44px' 'an icon fills its tile exactly'
css_assert 'article__share-link svg\{[^}]*width:22px' 'share icons size to their tile'
css_assert_not 'article__neighbors\{[^}]*border-top' 'previous and next sit apart by space, not a rule'
css_assert 'article__neighbors-link\{[^}]*flex:1 1 240px' 'prev and next split the column'
css_assert_not 'article__related-list' 'related reuses the card grid, no list of its own'
if rel_out=$(python3 - "$OUT" <<'PY'
import html
import re
import sys
from pathlib import Path

out = Path(sys.argv[1])
failed = []

def page(rel):
    return (out / rel / "index.html").read_text(encoding='utf-8')

def block(text, cls, tag):
    m = re.search(r'<%s class="%s".*?</%s>\s*' % (tag, cls, tag), text, re.S)
    return html.unescape(m.group(0)) if m else ""

# --- related: a lazy card grid, capped, and hidden when there is nothing ---
vec = page("section-a/vector")
for rel in ("section-a/vector", "section-a/flat"):
    related = block(page(rel), "article__related", "section")
    if not related:
        failed.append("%s renders no related block" % rel)
        continue
    if 'aria-labelledby="article-related"' not in related:
        failed.append("%s: related block does not point at its heading" % rel)
    if '<h2 class="article__related-title" id="article-related">Related</h2>' not in related:
        failed.append("%s: related heading is missing or mislabelled" % rel)
    if 'class="page-collection page-collection--grid"' not in related:
        failed.append("%s: related does not render the card grid" % rel)
    if 'class="article__related-list"' in related:
        failed.append("%s: related still renders its own link list" % rel)
    cards = re.findall(r'<article class="card card--grid"', related)
    if not cards:
        failed.append("%s: related block renders no cards" % rel)
    if len(cards) > 3:
        failed.append("%s: relatedContentLimit = 3 not honoured (%d cards)" % (rel, len(cards)))
    if 'loading="eager"' in related:
        failed.append("%s: a related card fetches its image eagerly" % rel)
    for href, title in re.findall(r'<a class="card__link" href="([^"]+)">([^<]+)</a>', related):
        if not (out / href.lstrip("/") / "index.html").exists():
            failed.append("%s: related link points at an unbuilt page: %s" % (rel, href))
        if not title.strip():
            failed.append("%s: related link renders an empty title" % rel)
if "article__related" in page("section-a/pixel"):
    failed.append("an empty related result still renders a block")

# --- meta separator: exactly one · between adjacent items ---
for rel in ("section-a/vector", "section-a/flat", "section-a/nested/post", "section-a/anim", "section-a/pixel"):
    for m in re.finditer(r'<p class="article__meta">(.*?)</p>', page(rel), re.S):
        inner = " ".join(html.unescape(m.group(1)).split())
        if not inner:
            continue
        items = len(re.findall(r"<time", inner)) + inner.count('class="article__tag"')
        items += 1 if "By " in inner else 0
        segments = len([s for s in inner.split(" · ") if s.strip()])
        if segments != items:
            failed.append("%s meta has %d item(s) but %d separator-run(s): %r"
                          % (rel, items, segments, inner))
        if inner.startswith("·") or inner.rstrip().endswith("·"):
            failed.append("%s meta has a leading or trailing separator: %r" % (rel, inner))

# --- updated date: shown only when lastmod is later than date, page false wins ---
if not re.search(r'<p class="article__meta">\s*<time[^>]*datetime="2020-01-04">4 Jan 2020</time>\s*·\s*Updated\s*<time[^>]*datetime="2020-06-01">1 Jun 2020</time>',
                 page("section-a/anim"), re.S):
    failed.append("a lastmod newer than date renders no Updated line")
for rel, why in (("section-a/nested/post", "a lastmod earlier than date renders an Updated line"),
                 ("section-a/pixel", "showDateUpdated = false still renders an Updated line"),
                 ("section-a/flat", "lastmod equal to date renders an Updated line"),
                 ("section-a/vector", "lastmod equal to date renders an Updated line")):
    if "Updated" in page(rel):
        failed.append("%s: %s" % (rel, why))

# --- dateFormat: read from the language config, datetime attr stays ISO ---
if not re.search(r'<time datetime="2026-01-03">3 Jan 2026</time>', page("section-a/flat")):
    failed.append("language-level dateFormat is not honoured")
for rel in ("section-a",):
    list_page = page(rel)
    if "3 Jan 2026" not in list_page:
        failed.append("list cards ignore the language dateFormat")

flat = page("section-a/flat")
if not re.search(r'<p class="article__meta">\s*<time', flat, re.S):
    failed.append("the default showDate = true renders no date")
if re.search(r'<p class="article__meta">\s*<time', vec, re.S):
    failed.append("showDate = false still renders a date")

# --- sharing: one 44px tile per sharingLinks name, icon with a text fallback ---
share = block(flat, "article__share", "div")
if not share:
    failed.append("flat renders no share block")
else:
    if 'role="group"' not in share or 'aria-label="Share this article"' not in share:
        failed.append("share block is not an accessible group")
    if re.search(r'href="[^"]* [^"]*"', share):
        failed.append("a share URL left a raw space unencoded")
    links = re.findall(
        r'<a class="article__share-link" href="([^"]+)" aria-label="([^"]+)"'
        r'( target="_blank" rel="noopener noreferrer")?>(.*?)</a>',
        share, re.S)
    if len(links) != 4:
        failed.append("expected 4 share links, got %d" % len(links))
    if len({label for _, label, _, _ in links}) != len(links):
        failed.append("a sharingLinks service renders twice")
    # Hugo 0.167.0's default baseURL is absolute, so .Permalink — and therefore
    # the share URL — renders absolute. Older Hugo leaves it relative. Both
    # forms are valid, so pin the page URL the build produced rather than the
    # shape it takes; the thing under test is the URL and title encoding.
    m = re.search(r'rel="canonical" href="([^"]+)"', flat)
    purl = m.group(1) if m else "/section-a/flat/"
    expect = {
        "LinkedIn": ("https://www.linkedin.com/shareArticle?mini=true&url=%s&title=Flat+section+image" % purl, True),
        "Facebook": ("https://www.facebook.com/sharer/sharer.php?u=%s&quote=Flat+section+image" % purl, True),
        "Email":    ("mailto:?body=%s&subject=Flat+section+image" % purl, False),
        "WhatsApp": ("https://api.whatsapp.com/send?text=Flat+section+image+%s" % purl, True),
    }
    for url, label, blank, body in links:
        want = expect.get(label)
        if want is None:
            failed.append("an unexpected share service renders: %r" % label)
            continue
        if (url, bool(blank)) != want:
            failed.append("%s share link is %r, want %r" % (label, (url, bool(blank)), want))
        if "<svg" not in body or "viewBox" not in body:
            failed.append("%s share tile renders no icon" % label)

# --- neighbors: the section's own prev/next, gated by showPagination ---
nb = block(flat, "article__neighbors", "nav")
if not nb:
    failed.append("flat renders no adjacent-article nav")
else:
    if 'aria-label="Adjacent articles"' not in nb:
        failed.append("the adjacent-article nav does not name itself")
    for want, why in (
        (r'<a class="article__neighbors-link" href="([^"]+)" rel="prev">', "previous"),
        (r'<a class="article__neighbors-link article__neighbors--next" href="([^"]+)" rel="next">', "next")):
        m = re.search(want, nb)
        if not m:
            failed.append("flat renders no %s-article link" % why)
            continue
        if not (out / m.group(1).lstrip("/") / "index.html").exists():
            failed.append("the %s-article link points at an unbuilt page" % why)
    if 'class="article__neighbors-label"' not in nb:
        failed.append("an adjacent-article link renders no label")
    if 'class="article__neighbors-title"' not in nb:
        failed.append("an adjacent-article link renders no title")
if "article__neighbors" in page("section-a/pixel"):
    failed.append("showPagination = false still renders an adjacent-article nav")

for rel in ("notice", "section-a"):
    if any(cls in page(rel) for cls in ("article__share", "article__related", "article__neighbors")):
        failed.append("%s is not an article but renders article chrome" % rel)

if failed:
    for line in failed:
        print("FAIL " + line, file=sys.stderr)
    sys.exit(1)
print("related card grid, 4 share tiles, adjacent articles, meta separators, empty results hidden")
PY
); then
  pass "related, meta separators and share render only on articles ($rel_out)"
else
  fail 'related, meta separators and share render only on articles'
fi

 # scripts/lib/build_config.py resolves the same config pair Hugo merges: the
# theme's config/_default/params.toml underneath a site's own. Assert the merge semantics, so
# a ladder, cap or budget can never drift back into a template or a script.
CFG_DEFAULT="$(python3 "$ROOT/scripts/lib/build_config.py")"
CFG_DIR="$(mktemp -d)"
mkdir -p "$CFG_DIR/config/_default"
cat > "$CFG_DIR/config/_default/params.toml" <<'EOF'
[params.image.og]
  width = 1400
[params.build]
  pageimageskb = 450
[params.build.minwidth]
  illustration = 1500
EOF
CFG_SITE="$(python3 "$ROOT/scripts/lib/build_config.py" --site "$CFG_DIR")"
rm -rf "$CFG_DIR"
CFG_OWN='^export (OG_WIDTH|PAGE_IMAGES_KB|MIN_WIDTH_ILLUSTRATION)='

# The last clause is the real contract: the rules run in a python subprocess
# and read the thresholds through os.environ, so an assignment that is not
# exported cannot reach them and every threshold reverts to its default.
if ( eval "$CFG_SITE" && [ "$OG_WIDTH" -eq 1400 ] && [ "$PAGE_IMAGES_KB" -eq 450 ] \
     && [ "$MIN_WIDTH_ILLUSTRATION" -eq 1500 ] && [ "$MIN_WIDTH_HERO" -eq 1600 ] \
     && python3 -c "import os, sys; sys.exit(0 if os.environ.get('MAX_FILES') else 1)" ); then
  pass 'build_config applies a site override over the theme defaults'
else
  fail 'build_config applies a site override over the theme defaults'
fi

if diff <(printf '%s\n' "$CFG_DEFAULT" | grep -Ev "$CFG_OWN") \
        <(printf '%s\n' "$CFG_SITE" | grep -Ev "$CFG_OWN") >/dev/null; then
  pass 'build_config deep-merges: unset keys keep the theme defaults'
else
  fail 'build_config deep-merges: unset keys keep the theme defaults'
fi

# The environment overlay is honoured the way Hugo honours it: config/dev/ wins
# for --environment dev and is invisible for the production default.
CFG_ENV="$(mktemp -d)"
mkdir -p "$CFG_ENV/config/dev"
cat > "$CFG_ENV/config/dev/params.toml" <<'EOF'
[params.build]
  pageimageskb = 400
EOF
CFG_DEV="$(python3 "$ROOT/scripts/lib/build_config.py" --site "$CFG_ENV" --environment dev)"
CFG_PROD="$(python3 "$ROOT/scripts/lib/build_config.py" --site "$CFG_ENV")"
rm -rf "$CFG_ENV"

if ( eval "$CFG_DEV" && [ "$PAGE_IMAGES_KB" -eq 400 ] ) \
    && ( eval "$CFG_PROD" && [ "$PAGE_IMAGES_KB" -eq 600 ] ); then
  pass 'build_config honours --environment the way Hugo does'
else
  fail 'build_config honours --environment the way Hugo does'
fi

# A key declared in two config layers resolves by precedence, never by union:
# Hugo keeps the higher-precedence value and drops the lower one, so a
# disableKinds split across _default and an environment disables exactly what
# the build disables. The site gate reads those same layers through _merge, so
# this pins both readings to hugo config: a reading that added them together
# would report taxonomy and term both off while the build still emitted /tags.
CFG_KINDS="$(mktemp -d)"
mkdir -p "$CFG_KINDS/config/_default" "$CFG_KINDS/config/production"
printf 'disableKinds = ["taxonomy"]\n' >"$CFG_KINDS/config/_default/hugo.toml"
printf 'disableKinds = ["term"]\n' >"$CFG_KINDS/config/production/hugo.toml"
KINDS_PROD="$(hugo --source "$CFG_KINDS" config --environment production 2>/dev/null \
  | grep -i '^disablekinds' || true)"
KINDS_DEV="$(hugo --source "$CFG_KINDS" config --environment dev 2>/dev/null \
  | grep -i '^disablekinds' || true)"
KINDS_MERGE="$(python3 - "$ROOT" <<'PY'
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(sys.argv[1]) / "scripts" / "lib"))
from build_config import _merge
print(repr(_merge({"disableKinds": ["taxonomy"]}, {"disableKinds": ["term"]})))
PY
)"
rm -rf "$CFG_KINDS"

if printf '%s' "$KINDS_PROD" | grep -q 'term' \
  && ! printf '%s' "$KINDS_PROD" | grep -q 'taxonomy' \
  && printf '%s' "$KINDS_DEV" | grep -q 'taxonomy' \
  && printf '%s' "$KINDS_MERGE" | grep -qF "'disableKinds': ['term']"
then
  pass 'a config-layer array resolves by precedence, not by union'
else
  fail 'a config-layer array resolves by precedence, not by union'
fi

# 49. security: static/_headers ships a strict Content-Security-Policy and no
#     page ships an executable inline script. Together they are what make the
#     policy enforceable. Two deliberate exceptions, both documented in
#     _headers: json-ld blocks carry a non-executable script type and are
#     exempt from script-src, and the AdSense push runs the third-party loader
#     the ads shortcode registers.
assert_at "$ROOT/static" '_headers' "script-src 'self'" \
  'headers ship a strict script-src with no unsafe-inline'
assert_at "$ROOT/static" '_headers' 'X-Content-Type-Options: nosniff' \
  'headers set nosniff'
assert_at "$ROOT/static" '_headers' 'Referrer-Policy: strict-origin-when-cross-origin' \
  'headers set a referrer policy'
assert_at "$ROOT/static" '_headers' 'object-src .none' \
  'headers deny plugins'
# Comments are stripped first: the file documents the AdSense relaxation in
# prose, and style-src legitimately keeps 'unsafe-inline' for the carousel's
# dynamic aspect-ratio attribute.
HDRS="$(grep -vE '^[[:space:]]*#' "$ROOT/static/_headers")"
if printf '%s\n' "$HDRS" | grep -qE 'script-src[^;]*unsafe-inline'; then
  fail 'no script-src relaxation sneaks into the policy'
else
  pass 'no script-src relaxation sneaks into the policy'
fi
if EXEC_INLINE=$(python3 - "$OUT" <<'PY'
import re
import sys
from pathlib import Path

bad = []
for page in Path(sys.argv[1]).rglob("*.html"):
    for tag, body in re.findall(r"<script(?![^>]*\bsrc=)([^>]*)>(.*?)</script>", page.read_text(encoding="utf-8"), re.S):
        if "ld+json" in tag or "adsbygoogle" in body:
            continue
        bad.append(f"{page.name}: {body.strip()[:48]}")
print("\n".join(bad))
PY
) && [ -z "$EXEC_INLINE" ]; then
  pass 'no page ships an executable inline script'
else
  printf '%s\n' "$EXEC_INLINE" >&2
  fail 'no page ships an executable inline script'
fi

# 53. A page summary renders as a standfirst, only when the page supplies one.
#     [article].showSummary defaults to true: a page's own summary is written
#     for a reader, unlike [list].showSummary which is about cards.
assert 'section-a/inline/index.html' \
  '<p class="article__standfirst">Inline illustration summary</p>' \
  'a page summary renders as a standfirst'
assert_not 'section-a/flat/index.html' 'article__standfirst' \
  'a page without a summary ships no standfirst'
if grep -q 'article__standfirst' "$OUT_NOSUMMARY/section-a/inline/index.html"; then
  fail '[article].showSummary = false still renders a standfirst'
else
  pass '[article].showSummary = false removes the standfirst'
fi

# 54. An author url turns the byline into a link and reaches the JSON-LD
#     Person. The theme takes a URL rather than a taxonomy because Hugo
#     reserves the author key for authorship, so `author = "authors"` under
#     [taxonomies] is ignored and no term page is ever built.
assert 'section-a/flat/index.html' \
  '<a class="article__author" href="/notice/">Flat Author</a>' \
  'an author url turns the byline into a link'
assert 'section-a/flat/index.html' \
  '"author":\{[^}]*"url":"[^"]*notice/"' \
  'the Person entity carries the author url'
assert_not 'section-a/inline/index.html' 'article__author' \
  'a page without an author url keeps a plain-text byline'

# 55. A content link to another host opens a new tab, so a reference never
#     takes a reader out of the article, and carries a marker so the reader
#     sees the tab stays behind. The marker is a real element rather than
#     ::after content, so screen readers skip it instead of reading "arrow"
#     after every link. The anchor also carries class="link--external", which
#     is the hook a site needs to style external links as a group rather than
#     reaching through the marker with a:has(.link__icon). Internal and
#     mailto links never do any of this: site navigation has to stay in the
#     tab. The notab overlay proves the switch is the theme's config deciding,
#     not the shape of a URL.
assert 'section-a/links/index.html' \
  'href="https://gohugo.io" class="link--external" target="_blank" rel="noopener noreferrer"' \
  'an external content link opens in a new tab'
assert 'section-a/links/index.html' \
  '<span class="link__icon" aria-hidden="true">&#8599;&#65038;</span>' \
  'a new-tabbed link carries a marker that assistive technology skips'
count_assert 'section-a/links/index.html' 'class="link__icon"' 2 \
  'only the external links carry a marker'
count_assert 'section-a/links/index.html' 'class="link--external"' 2 \
  'only the external links carry the class a site styles them by'
assert 'section-a/links/index.html' \
  'href="https://example.com/search\?q=strata&amp;lang=en"' \
  'a new-tabbed link keeps its escaped query string'
assert 'section-a/links/index.html' '<a href="/notice/">notice</a>' \
  'an internal content link stays in the tab'
assert 'section-a/links/index.html' \
  '<a href="mailto:hello&#64;example.com">email</a>' \
  'a mailto link stays in the tab, entity-encoded'
assert_at "$OUT_NOTAB" 'section-a/links/index.html' \
  '<a href="https://gohugo.io">Hugo docs</a>' \
  'externalLinksNewTab = false navigates the external link in place'
if grep -qE 'link__icon|link--external' "$OUT_NOTAB/section-a/links/index.html"; then
  fail 'externalLinksNewTab = false still marks the external link'
else
  pass 'externalLinksNewTab = false drops the marker with the new tab'
fi

if [ "$FAILURES" -gt 0 ]; then
  printf 'smoke: %s failure(s)\n' "$FAILURES" >&2
  exit 1
fi
printf 'smoke: all assertions passed\n'

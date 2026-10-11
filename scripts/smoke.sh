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
WORK="$(mktemp -d)"
OUT="$WORK/public"
OUT_REMOTE="$WORK/public-remote"
trap 'rm -rf "$WORK"' EXIT
FAILURES=0

# css.TailwindCSS shells out to the standalone Tailwind v4 CLI, which must
# be on PATH (fail fast — without it every assertion below is noise)
if ! command -v tailwindcss >/dev/null 2>&1; then
  echo 'FAIL tailwindcss not on PATH — install the standalone v4 binary (see README)' >&2
  exit 1
fi

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
count_assert 'tags/index.html' 'term-text__count' 3 'all three terms show a count'

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
count_assert 'section-a/shortcodes/index.html' 'sizes="\(min-width:912px\) 720px' 6 \
  'three figures, two slides and the loop clone carry the text sizes'
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
assert 'section-a/shortcodes/index.html' 'class="shortcode-list">' \
  'cardView=false selects the row branch (base class only)'
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
assert 'section-a/shortcodes/index.html' 'class="mgrid"' \
  'multi-col renders the container'
assert 'section-a/shortcodes/index.html' 'style="[^"]*mgrid-template: 2fr 1fr' \
  'multi-col honours the ratio parameter'
count_assert 'section-a/shortcodes/index.html' 'class="mcol"' 2 \
  'columns render the mcol class set'

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

# 24. the stylesheet comes from the in-process Tailwind pipeline, not a
#     committed bundle: no css/compiled reference may survive, and the built
#     theme CSS must carry a component rule only the sources provide
if grep -rq 'css/compiled' "$ROOT/layouts" "$ROOT/assets/css/main.css" 2>/dev/null; then
  fail 'stale css/compiled reference survives in layouts or CSS entry'
else
  pass 'no css/compiled references remain'
fi
theme_built=$(ls "$OUT"/css/theme*.css 2>/dev/null | head -1)
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
  f=$(ls "$OUT"/css/theme*.css 2>/dev/null | head -1)
  if [ -n "$f" ] && grep -qE -e "$1" "$f"; then pass "$2"; else fail "$2"; fi
}
css_assert 'max-width:720px' 'prose caps at 720px (text preset)'
css_assert 'width:200px' 'row thumb is fixed at 200px (row/inline preset)'
css_assert 'repeat\(3,minmax\(0,1fr\)\)' 'three columns from 853px (grid preset)'
css_assert 'repeat\(2,minmax\(0,1fr\)\)' 'two columns from 640px (grid preset)'
css_assert '@media\(min-width:853px\)\{:root\{--site-gutter:96px' \
  'gutter rung 96px sits at the 853px breakpoint'
css_assert ':root\{--site-gutter:24px;--site-content:1024px\}' \
  'base gutter 24px and content cap 1024px'
css_assert '@media\(min-width:640px\)\{:root\{--site-gutter:56px' \
  'gutter rung 56px sits at the 640px breakpoint'
css_assert '@media\(min-width:1024px\)\{:root\{--site-gutter:128px' \
  'gutter rung 128px sits at the 1024px breakpoint'
css_assert '--site-accent:#295f8f' 'default scheme accent is linked in'
count_assert 'section-a/shortcodes/index.html' '\(min-width:832px\) 720px' 6 \
  'text preset adds the 832px rung on every body image and the loop clone'

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
css_assert 'prose\{[^}]*max-width:720px' \
  '.prose rule carries 720px, not the plugin 65ch'

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
  pass "every tag and series link points at a built page ($tax_out)"
else
  fail 'every tag and series link points at a built page'
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
assert 'index.html' 'info&#64;example\.net' 'footer email is entity-obfuscated'
assert 'index.html' 'Testville' 'footer address second line renders'
assert 'index.html' 'aria-label="Check"' 'footer social icon link renders'
assert 'index.html' '>Fallback<' 'missing social icon falls back to the name'
assert 'index.html' 'site-header__toggle" data-appearance-toggle' 'switcher sits in the header'
assert 'index.html' 'class="back-to-top" data-scroll-top' 'scroll-to-top floats at the viewport corner'
assert 'index.html' 'aria-label="Back to top"' 'scroll-to-top is labelled'
assert 'index.html' 'site-footer__bottom' 'rich footer bottom travels as one bar'
assert_not 'index.html' 'site-footer__title' 'rich footer drops the duplicate identity block'

# 33. breadcrumbs: article and section trails link Home and ancestors,
#     the current page is plain text; taxonomy follows its table, term and
#     home stay hidden by default
assert 'section-a/flat/index.html' 'aria-label="Breadcrumb"' 'article breadcrumb renders'
assert 'section-a/flat/index.html' 'href="/"[^>]*>Home<' 'article trail starts at Home'
assert 'section-a/flat/index.html' 'href="/section-a/"[^>]*>Section A<' 'article trail links the section'
assert 'section-a/flat/index.html' 'aria-current="page"' 'current page is marked'
assert 'section-a/index.html' 'aria-label="Breadcrumb"' 'section trail renders via page override'
assert 'tags/index.html' 'aria-label="Breadcrumb"' 'taxonomy trail follows its table'
assert_not 'tags/alpha/index.html' 'aria-label="Breadcrumb"' 'term trail stays hidden by default'
assert_not 'index.html' 'aria-label="Breadcrumb"' 'home trail stays hidden by default'
# 33b. list headers share the article rhythm: the trail renders inside
#      .page-header ahead of the h1 (a trail outside the header once left
#      list pages 40px below the trail while articles sat 16px)
if python3 - "$OUT" <<'PY'
import pathlib, sys
for rel in ('section-a/index.html', 'tags/index.html'):
    html = (pathlib.Path(sys.argv[1]) / rel).read_text()
    hi = html.find('<header class="page-header">')
    ni = html.find('<nav aria-label="Breadcrumb">')
    ti = html.find('<h1>')
    assert hi != -1 and hi < ni < ti, rel
PY
then
  pass 'list trail sits inside the header ahead of the title'
else
  fail 'list trail sits inside the header ahead of the title'
fi
css_assert 'page-header\{margin-block:0 12px' 'list header carries no top gap of its own'
css_assert 'page-header:not\(:has\(.breadcrumb\)\)\{margin-top:40px' 'trail-less header keeps its top air'

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
#     both gated by showAuthor
assert 'section-a/flat/index.html' 'By Flat Author' 'page author renders'
assert 'section-a/nested/post/index.html' 'By Fixture Team' 'site author is the fallback'

# 36. carousel loop is seamless: a hidden clone of the first slide closes
#     the track so last-to-first animates instead of jumping
count_assert 'section-a/shortcodes/index.html' 'data-carousel-slide' 2 \
  'carousel keeps two real slides'
assert 'section-a/shortcodes/index.html' 'aria-hidden="true" tabindex="-1"' \
  'carousel appends a hidden first-slide clone'

# 37. article-vs-page width: sections in mainSections stay prose-capped,
#     standalone pages render full width
assert 'notice/index.html' 'class="page--wide"' 'non-article single goes full width'
assert_not 'section-a/flat/index.html' 'page--wide' 'article single stays capped'
# 44. list and single pages share one top rhythm: the article header
#     carries no top margin of its own (hero images keep their own spacing)
css_assert 'article__header\{max-width:720px;margin:0 auto' 'article header starts at the shared offset'
# 45. mobile disclosure menu: hamburger with synced state, nested
#     submenu behind a chevron button, loader wired
assert 'index.html' 'data-nav-toggle aria-expanded="false"' 'hamburger starts collapsed'
assert 'index.html' 'data-nav-subtoggle' 'parent gets a submenu chevron'
assert 'index.html' 'href="/section-a/flat/"' 'nested entry links its page'
assert 'index.html' 'menu\.[0-9a-f]+\.js' 'menu script loads'
assert 'index.html' 'aria-controls="site-navigation"' 'hamburger names its panel'
assert 'index.html' 'id="site-navigation" data-nav-panel' 'panel carries the named id'
assert 'index.html' 'class="site-nav__sub" id="nav-sub-[0-9]*" hidden' 'submenu starts hidden'
css_assert 'site-header\{--header-bar:68px;position:relative' 'standard header anchors the mobile panel'
css_assert 'site-nav__link\[aria-current=page\]\{[^}]*font-weight:600' 'active nav item has a non-color cue'
css_assert 'site-footer__link\[aria-current=page\]\{[^}]*font-weight:600' 'active footer item has a non-color cue'
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
#     (same pattern as #43 — markup cannot show it)
if grep -q '"Escape"' "$ROOT/assets/js/menu.js" &&
   grep -q 'btn.focus()' "$ROOT/assets/js/menu.js"; then
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
   grep -q '"Escape"' "$ROOT/assets/js/search.js" &&
   grep -q 'data-nav-panel' "$ROOT/assets/js/search.js" &&
   grep -q 'data-search-panel' "$ROOT/assets/js/menu.js" &&
   grep -q 'list.addEventListener("click"' "$ROOT/assets/js/search.js"; then
  pass 'search scores, escapes and shares the panel contract'
else
  fail 'search scores, escapes and shares the panel contract'
fi
css_assert 'article__header h1,.page-header h1\{font-size:2.125rem' 'page titles share one size rule'
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

# 39. scheme contrast: every colour scheme keeps white-on-accent/strong
#     at 4.5:1 and ring at 3:1 in both modes (a pale dark-mode accent once
#     shipped below 2:1 on real buttons)
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

def block_vars(text, selector):
    m = re.search(re.escape(selector) + r'\s*\{([^}]*)\}', text)
    out = {}
    if m:
        for k, v in re.findall(r'(--[\w-]+)\s*:\s*(#[0-9a-fA-F]{6})', m.group(1)):
            out[k] = v
    return out

pal = (root / 'assets/css/base/palette.css').read_text()
light_bg = block_vars(pal, ':root')['--page-bg']
dark_bg = block_vars(pal, ':root.dark')['--page-bg']
bad = []
for p in sorted((root / 'assets/css/schemes').glob('*.css')):
    css = p.read_text()
    for mode, bg in ((':root', light_bg), (':root.dark', dark_bg)):
        v = block_vars(css, mode)
        for key in ('--site-accent', '--site-accent-strong'):
            if key in v and ratio('#ffffff', v[key]) < 4.5:
                bad.append(f'{p.name} {mode} white-on-{key} {v[key]}')
        if '--site-link' in v and ratio(v['--site-link'], bg) < 4.5:
            bad.append(f'{p.name} {mode} link-on-bg {v["--site-link"]}')
        if '--site-ring' in v and ratio(v['--site-ring'], bg) < 3.0:
            bad.append(f'{p.name} {mode} ring-on-bg {v["--site-ring"]}')
if bad:
    for b in bad:
        print(f'FAIL {b}')
    sys.exit(1)
print('all schemes hold contrast in both modes')
PY
); then
  pass "scheme contrast holds ($contrast_out)"
else
  printf '%s\n' "$contrast_out" >&2
  fail 'every scheme holds text and focus contrast'
fi

# 40. keyboard and assistive-tech paths: skip link, carousel arrows and
#     reduced-motion guards, contact live region and invalid flag
assert 'index.html' 'class="skip-link" href="#main-content"' 'skip link targets the main block'
assert 'section-a/shortcodes/index.html' 'ArrowLeft' 'carousel handles arrow keys'
assert 'section-a/shortcodes/index.html' 'prefers-reduced-motion' 'carousel honours reduced motion'
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
assert 'index.html' '"@type":"Organization"' 'schema carries the publisher once'

if [ "$FAILURES" -gt 0 ]; then
  printf 'smoke: %s failure(s)\n' "$FAILURES" >&2
  exit 1
fi
printf 'smoke: all assertions passed\n'

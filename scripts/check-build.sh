#!/usr/bin/env bash
# Assert the rules Strata guarantees in its build output.
#
# Usage: ./scripts/check-build.sh <public_dir> [--mode theme|site]
#
# Shared by validate-theme.sh and validate-site.sh so the rule set stays
# in one place. <public_dir> is a finished Hugo build; nothing is built
# here. Rules are grouped by concern: SEO, schema, images, links, assets.
# Absolute URLs are mapped onto the output tree by path only, so a remote
# image on an allowed domain is skipped rather than misreported; baseURL
# misconfiguration is caught by the canonical and link rules instead.
set -euo pipefail

PUBLIC=""
MODE="theme"
while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="${2:?--mode needs theme or site}"; shift 2 ;;
    -*) printf 'unknown flag: %s\n' "$1" >&2; exit 2 ;;
    *) PUBLIC="$1"; shift ;;
  esac
done
case "$MODE" in theme|site) ;; *) printf 'unknown mode: %s\n' "$MODE" >&2; exit 2 ;; esac
if [ -z "$PUBLIC" ] || [ ! -d "$PUBLIC" ]; then
  printf 'Usage: ./scripts/check-build.sh <public_dir> [--mode theme|site]\n' >&2
  exit 2
fi

FAILURES=0
pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }

if report=$(python3 - "$PUBLIC" <<'PY'
import json
import re
import sys
from pathlib import Path

pub = Path(sys.argv[1])
TEXT_EXT = {'.html', '.xml', '.json', '.css', '.txt', '.webmanifest'}
IMG_EXT = {'.webp', '.jpg', '.jpeg', '.png', '.gif', '.svg', '.avif', '.ico'}
FAVICON_RE = re.compile(r'(favicon|apple-touch-icon|android-chrome|safari-pinned-tab|mstile|browserconfig)', re.I)
PAGE_BUDGET = 600 * 1024

problems = []


def ok(label):
    print(f'ok   {label}')


def bad(label, detail=''):
    problems.append(label)
    print(f'FAIL {label}')
    if detail:
        print(detail)


def local_path(url):
    url = url.split('#')[0].split('?')[0]
    if url.startswith('/'):
        return url
    m = re.match(r'^https?://[^/]+(/.*)?$', url)
    if m:
        return m.group(1) or '/'
    return None


def exists(rel):
    p = pub / rel.lstrip('/')
    if p.is_file():
        return True
    return (p / 'index.html').is_file()


def expand_srcset(attr):
    urls = set()
    for candidate in attr.split(','):
        parts = candidate.strip().split()
        if parts:
            urls.add(parts[0])
    return urls


files = [p for p in pub.rglob('*') if p.is_file()]
texts = [p for p in files if p.suffix.lower() in TEXT_EXT]
images = [p for p in files if p.suffix.lower() in IMG_EXT]
htmls = [p for p in files if p.suffix == '.html']

src_attr = re.compile(r'\b(?:src|href|content|url)=["\x27]([^"\x27]+)["\x27]', re.I)
srcset_attr = re.compile(r'\b(?:srcset|imagesrcset)=["\x27]([^"\x27]+)["\x27]', re.I)
css_url = re.compile(r'url\(["\x27]?([^"\x27)]+)["\x27]?\)')

referenced = set()
per_page = {}
download_attr = re.compile(r'\b(?:src|href)=["\x27]([^"\x27]+)["\x27]', re.I)
for t in texts:
    text = t.read_text(errors='ignore')
    urls = set()
    dl = set()
    for attr in srcset_attr.findall(text):
        urls |= expand_srcset(attr)
        dl |= expand_srcset(attr)
    for m in src_attr.findall(text):
        urls.add(m.strip().split()[0] if m.strip() else m)
    for m in download_attr.findall(text):
        dl.add(m.strip().split()[0] if m.strip() else m)
    for m in css_url.findall(text):
        urls.add(m)
        dl.add(m)
    local = {u for u in urls if local_path(u)}
    referenced |= local
    if t.suffix == '.html':
        per_page[t] = {u for u in dl if local_path(u)}

# R1 every referenced local image file exists
broken = sorted({local_path(u) for u in referenced
                 if Path(local_path(u)).suffix.lower() in IMG_EXT and not exists(local_path(u))})
if broken:
    bad('referenced images exist', '\n'.join(f'  {b}' for b in broken))
else:
    ok('referenced images exist')

# R2 every local <img> of a pipeline-resized format carries srcset, and
#    every <img> carries a real alt. Hugo names processed variants with a
#    `_hu_<hash>` segment; static files and disableImageOptimization pass
#    through with their original names and legitimately have no srcset.
bad_imgs = []
for t, text in ((t, t.read_text(errors='ignore')) for t in htmls):
    for tag in re.findall(r'<img\b[^>]*>', text, re.I):
        src = re.search(r'\bsrc=["\x27]([^"\x27]*)["\x27]', tag, re.I)
        if not src or not local_path(src.group(1)):
            continue
        base = Path(local_path(src.group(1))).name
        ext = Path(local_path(src.group(1))).suffix.lower()
        if (ext in {'.jpg', '.jpeg', '.png'} and '_hu_' in base
                and not re.search(r'\bsrcset=["\x27][^"\x27]+["\x27]', tag, re.I)):
            bad_imgs.append(f'{t.relative_to(pub)}: no srcset ({src.group(1)})')
        alt = re.search(r'\balt=["\x27]([^"\x27]*)["\x27]', tag, re.I)
        if alt is None:
            bad_imgs.append(f'{t.relative_to(pub)}: no alt ({src.group(1)})')
        elif alt.group(1) == '' and 'aria-hidden="true"' not in tag:
            bad_imgs.append(f'{t.relative_to(pub)}: empty alt without aria-hidden ({src.group(1)})')
if bad_imgs:
    bad('local images carry srcset and alt', '\n'.join(f'  {b}' for b in bad_imgs))
else:
    ok('local images carry srcset and alt')

# R3 preload imagesrcset is a subset of some <img> srcset on the same page
subset_bad = []
for t in htmls:
    text = t.read_text(errors='ignore')
    preloads = re.findall(r'<link\b[^>]*rel=["\x27]preload["\x27][^>]*>', text, re.I)
    img_sets = []
    for tag in re.findall(r'<img\b[^>]*>', text, re.I):
        m = re.search(r'\bsrcset=["\x27]([^"\x27]+)["\x27]', tag, re.I)
        if m:
            img_sets.append(expand_srcset(m.group(1)))
    for tag in preloads:
        m = re.search(r'\bimagesrcset=["\x27]([^"\x27]+)["\x27]', tag, re.I)
        if not m:
            continue
        urls = {local_path(u) for u in expand_srcset(m.group(1))}
        if not any(urls <= {local_path(u) for u in s} for s in img_sets):
            subset_bad.append(str(t.relative_to(pub)))
if subset_bad:
    bad('preload candidates are a subset of the page srcset', '\n'.join(f'  {b}' for b in subset_bad))
else:
    ok('preload candidates are a subset of the page srcset')

# R4 no orphan images: every image file is referenced from some text output
#    (favicon-family files are exempt — they are linked from nowhere)
refd_paths = {local_path(u) for u in referenced}
orphans = sorted(str(p.relative_to(pub)) for p in images
                 if f'/{p.relative_to(pub)}' not in refd_paths and not FAVICON_RE.search(p.name))
if orphans:
    bad('no orphan images', '\n'.join(f'  {o}' for o in orphans))
else:
    ok('no orphan images')

# R5 per-page image payload stays inside the budget
worst = ('', 0)
for t, urls in per_page.items():
    total = 0
    for u in urls:
        rel = local_path(u)
        if Path(rel).suffix.lower() in IMG_EXT and exists(rel):
            total += (pub / rel.lstrip('/')).stat().st_size
    if total > worst[1]:
        worst = (str(t.relative_to(pub)), total)
site_total = sum(p.stat().st_size for p in images)
print(f'info page image payload: max {worst[1] // 1024}KB ({worst[0]}), site {site_total // 1024}KB')
if worst[1] > PAGE_BUDGET:
    bad(f'page image payload within {PAGE_BUDGET // 1024}KB', f'  {worst[0]}: {worst[1] // 1024}KB')
else:
    ok(f'page image payload within {PAGE_BUDGET // 1024}KB')

# R6 canonical is present and self-referential
canon_bad = []
for t in htmls:
    text = t.read_text(errors='ignore')
    m = re.search(r'<link\b[^>]*rel=["\x27]canonical["\x27][^>]*href=["\x27]([^"\x27]+)["\x27]', text, re.I)
    if t.name == '404.html':
        continue
    if not m:
        canon_bad.append(f'{t.relative_to(pub)}: no canonical')
        continue
    rel = t.relative_to(pub)
    if rel.as_posix() == 'index.html':
        want = '/'
    elif t.name == 'index.html':
        want = '/' + rel.parent.as_posix() + '/'
    else:
        want = '/' + rel.as_posix()
    # Hugo paginates page 1 into /page/1/ while the page keeps the base
    # permalink — the canonical rightly points at the base. For page 2+
    # hugo canonicalizes .Permalink to the listing base by design, which
    # keeps pagination from duplicating content in search engines.
    got = local_path(m.group(1))
    base_want = re.sub(r'/page/\d+/', '/', want, count=1)
    base_got = re.sub(r'/page/\d+/', '/', got, count=1)
    if got != want and base_got != base_want:
        canon_bad.append(f'{t.relative_to(pub)}: canonical {got} != {want}')
if canon_bad:
    bad('canonical present and self-referential', '\n'.join(f'  {b}' for b in canon_bad))
else:
    ok('canonical present and self-referential')

# R7 schema graph: WebSite on home, WebPage on every page, Article exactly
#    where og:type=article says there is one
schema_bad = []
for t in htmls:
    text = t.read_text(errors='ignore')
    # /page/1/ outputs are meta-refresh stubs pointing at the base URL
    if 'http-equiv="refresh"' in text:
        continue
    types = set()
    for blob in re.findall(r'application/ld\+json["\x27][^>]*>([^<]+)', text):
        try:
            data = json.loads(blob)
        except json.JSONDecodeError:
            schema_bad.append(f'{t.relative_to(pub)}: unparsable JSON-LD')
            continue
        nodes = data if isinstance(data, list) else [data]
        for node in nodes:
            if isinstance(node, dict) and '@type' in node:
                types.add(node['@type'])
    is_home = t.relative_to(pub).as_posix() == 'index.html'
    is_404 = t.name == '404.html'
    og = re.search(r'property=["\x27]og:type["\x27] content=["\x27](\w+)["\x27]', text)
    if is_home and 'WebSite' not in types:
        schema_bad.append(f'{t.relative_to(pub)}: home lacks WebSite')
    if not is_404 and 'WebPage' not in types:
        schema_bad.append(f'{t.relative_to(pub)}: lacks WebPage')
    if og and og.group(1) == 'article' and 'Article' not in types:
        schema_bad.append(f'{t.relative_to(pub)}: og:type=article but no Article')
    if og and og.group(1) == 'website' and 'Article' in types:
        schema_bad.append(f'{t.relative_to(pub)}: og:type=website but Article present')
if schema_bad:
    bad('schema graph matches the page kinds', '\n'.join(f'  {b}' for b in schema_bad))
else:
    ok('schema graph matches the page kinds')

# R8 no empty href/src, no javascript: links, no dev placeholders,
#    no .DS_Store in the output
link_bad = []
for t in htmls:
    text = t.read_text(errors='ignore')
    rel = t.relative_to(pub)
    if 'data-image-missing' in text:
        link_bad.append(f'{rel}: dev image placeholder leaked into the build')
    for tag in re.findall(r'<(?:a|img|script|link)\b[^>]*>', text, re.I):
        for attr in ('href', 'src'):
            m = re.search(rf'\b{attr}=["\x27]([^"\x27]*)["\x27]', tag, re.I)
            if not m:
                continue
            v = m.group(1).strip()
            if v == '' or v.lower().startswith('javascript:'):
                link_bad.append(f'{rel}: {attr}={v!r} on {tag[:60]}')
for p in files:
    if p.name == '.DS_Store':
        link_bad.append(f'{p.relative_to(pub)}: .DS_Store in output')
if link_bad:
    bad('no dead links, leaked placeholders or .DS_Store', '\n'.join(f'  {b}' for b in link_bad))
else:
    ok('no dead links, leaked placeholders or .DS_Store')

# R9 every referenced local non-image asset exists
asset_bad = []
for u in referenced:
    rel = local_path(u)
    if Path(rel).suffix.lower() in IMG_EXT:
        continue
    if Path(rel).suffix.lower() in {'.css', '.js', '.webmanifest', '.xml', '.json', '.txt'} and not exists(rel):
        asset_bad.append(rel)
if asset_bad:
    bad('referenced local assets exist', '\n'.join(f'  {b}' for b in sorted(asset_bad)))
else:
    ok('referenced local assets exist')

sys.exit(1 if problems else 0)
PY
); then
  printf '%s\n' "$report"
  pass "check-build: all rules passed ($MODE mode)"
else
  printf '%s\n' "$report" >&2
  fail "check-build: rules failed ($MODE mode)"
fi

if [ "$FAILURES" -gt 0 ]; then
  exit 1
fi

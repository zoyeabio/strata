#!/usr/bin/env bash
# Assert the rules Strata guarantees in its build output.
#
# Usage: ./scripts/check-build.sh <public_dir> [--mode theme|site] [--site <dir>] [--environment production]
#
# Shared by validate-theme.sh and validate-site.sh so the rule set stays
# in one place. <public_dir> is a finished Hugo build; nothing is built
# here. --site selects the site whose config supplies the thresholds; without
# it the theme defaults in config.toml apply. --environment names the config
# overlay that build used; it defaults to production, which is Hugo's own
# default, and must match a non-default build or the thresholds come from the
# wrong overlay. Rules are grouped by concern:
# SEO, schema, images, links, assets. Absolute URLs are mapped onto the
# output tree by path only, so a remote image on an allowed domain is skipped
# rather than misreported; baseURL misconfiguration is caught by the canonical
# and link rules instead.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLIC=""
MODE="theme"
SITE=""
ENVIRONMENT="production"
while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="${2:?--mode needs theme or site}"; shift 2 ;;
    --site) SITE="${2:?--site needs a directory}"; shift 2 ;;
    --environment) ENVIRONMENT="${2:?--environment needs a name}"; shift 2 ;;
    -*) printf 'unknown flag: %s\n' "$1" >&2; exit 2 ;;
    *) PUBLIC="$1"; shift ;;
  esac
done
case "$MODE" in theme|site) ;; *) printf 'unknown mode: %s\n' "$MODE" >&2; exit 2 ;; esac
if [ -z "$PUBLIC" ] || [ ! -d "$PUBLIC" ]; then
  printf 'Usage: ./scripts/check-build.sh <public_dir> [--mode theme|site] [--site <dir>] [--environment production]\n' >&2
  exit 2
fi

# Thresholds come from config, not from this file: the theme's config.toml
# merged with the site's own config. scripts/lib/build_config.py resolves the
# same file pair Hugo merges when it renders, so the scripts and the
# templates judge the same numbers. Needs python3 >= 3.11 for tomllib.
CFG_CMD=("$ROOT/scripts/lib/build_config.py" --environment "$ENVIRONMENT")
if [ -n "$SITE" ]; then CFG_CMD+=(--site "$SITE"); fi
if ! BUILD_CONFIG="$(python3 "${CFG_CMD[@]}")"; then
  printf 'ERROR: failed to resolve the build config (needs python3 >= 3.11)\n' >&2
  exit 2
fi
eval "$BUILD_CONFIG"


FAILURES=0
pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }

if report=$(python3 - "$PUBLIC" <<'PY'
import json
import os
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

pub = Path(sys.argv[1])
TEXT_EXT = {'.html', '.xml', '.json', '.css', '.txt', '.webmanifest'}
IMG_EXT = {'.webp', '.jpg', '.jpeg', '.png', '.gif', '.svg', '.avif', '.ico'}
FAVICON_RE = re.compile(r'(favicon|apple-touch-icon|android-chrome|safari-pinned-tab|mstile|browserconfig)', re.I)
# [params.build.pageimageskb] from config, via scripts/lib/build_config.py
PAGE_BUDGET = int(os.environ.get('PAGE_IMAGES_KB', 600)) * 1024

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


# R5 counts a page's downloadable images in candidate *groups*, not as one
# flat list. A srcset ladder is a single group because the browser fetches one
# rung from it. Summing every rung of every ladder reports a page far bigger
# than it can ever be, so the budget failed on real content while the fixture
# passed. A group contained in another never adds a download either — the hero
# <img> and the <link rel="preload" imagesrcset> that accelerates it carry the
# same rungs (R3 checks the preload is such a subset) — so those collapse too.
IMG_CARRIERS = re.compile(r'<(?:img|link|meta)\b[^>]*>', re.I)
ATTR_URL = re.compile(r'\b(?:src|href|content)=["\x27]([^"\x27]*)["\x27]', re.I)


def groups_for(tag):
    """The candidate sets one element can download."""
    ladders = [expand_srcset(a) for a in srcset_attr.findall(tag)]
    singles = [m for m in ATTR_URL.findall(tag) if m.strip()]
    if ladders:
        ladder = set()
        for cand in ladders:
            ladder |= cand
        ladder.update(singles)
        return [ladder]
    return [{u} for u in singles]


def collapse(groups):
    """Distinct candidate sets, no group contained in another."""
    seen = set()
    uniq = []
    for g in groups:
        if not g:
            continue
        if frozenset(g) not in seen:
            seen.add(frozenset(g))
            uniq.append(g)
    return [g for g in uniq if not any(g < other for other in uniq)]


files = [p for p in pub.rglob('*') if p.is_file()]
texts = [p for p in files if p.suffix.lower() in TEXT_EXT]
images = [p for p in files if p.suffix.lower() in IMG_EXT]
htmls = [p for p in files if p.suffix == '.html']

src_attr = re.compile(r'\b(?:src|href|content|url)=["\x27]([^"\x27]+)["\x27]', re.I)
srcset_attr = re.compile(r'\b(?:srcset|imagesrcset)=["\x27]([^"\x27]+)["\x27]', re.I)
css_url = re.compile(r'url\(["\x27]?([^"\x27)]+)["\x27]?\)')
json_url = re.compile(r':"((?:https?://)[^"]+)"')

referenced = set()
per_page = {}

# Site host from the home canonical: only same-host absolute URLs resolve
# into the output tree; anything else (ad loaders, verification files) is
# someone else's server and skips existence checks
site_host = ''
home_page = pub / 'index.html'
if home_page.is_file():
    m = re.search(r'rel=["\x27]canonical["\x27]\s+href=["\x27]([^"\x27]*)',
                  home_page.read_text(errors='ignore'))
    if m:
        hm = re.match(r'^https?://([^/]+)', m.group(1))
        if hm:
            site_host = hm.group(1).lower()


def is_site_url(u):
    u = u.strip()
    if u.startswith('/'):
        return True
    if u.startswith('//'):
        u = 'https:' + u
    m = re.match(r'^https?://([^/]+)', u)
    return bool(m) and m.group(1).lower() == site_host
for t in texts:
    text = t.read_text(errors='ignore')
    urls = set()
    dl = []
    for attr in srcset_attr.findall(text):
        urls |= expand_srcset(attr)
    for m in src_attr.findall(text):
        urls.add(m.strip().split()[0] if m.strip() else m)
    for m in css_url.findall(text):
        urls.add(m)
        dl.append({m})
    for tag in IMG_CARRIERS.findall(text):
        dl.extend(groups_for(tag))
    local = {u for u in urls if local_path(u) and is_site_url(u)}
    referenced |= local
    if t.suffix == '.html':
        raw = [{u for u in g if local_path(u) and is_site_url(u)} for g in dl]
        per_page[t] = collapse([g for g in raw if g])

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

# R5 per-page image payload stays inside the budget. Each candidate group
# counts its largest rung: that is the most one element can ever download.
worst = ('', 0)
for t, groups in per_page.items():
    total = 0
    for group in groups:
        sizes = []
        for u in group:
            rel = local_path(u)
            if Path(rel).suffix.lower() in IMG_EXT and exists(rel):
                sizes.append((pub / rel.lstrip('/')).stat().st_size)
        if sizes:
            total += max(sizes)
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
                # A bare attribute (href with no value) is a broken link too,
                # and it renders without the "=" the check above needs.
                if re.search(rf'(?<![\w-]){attr}(?![\w-])', tag, re.I):
                    link_bad.append(f'{rel}: bare {attr} attribute on {tag[:60]}')
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

# R10 social and temporal tags match the page kind: og:type=website pages
#    carry no article:* times, and no social image is ever the bare site
#    root (an empty image ref used to fall back to static/, whose relURL
#    is the root URL)
social_bad = []
for t in htmls:
    text = t.read_text(errors='ignore')
    if 'http-equiv="refresh"' in text:
        continue
    rel = t.relative_to(pub)
    og = re.search(r'property=["\x27]og:type["\x27] content=["\x27](\w+)["\x27]', text)
    # Match a real meta tag, not the substring anywhere: a docs page that
    # names the tag in prose or a table is not carrying it.
    if (not og or og.group(1) != 'article') and re.search(r'<meta[^>]*(?:property|name)=["\x27]article:(?:published|modified)_time["\x27]', text):
        social_bad.append(f'{rel}: article:* time on og:type={og.group(1) if og else "?"}')
    for prop in ('og:image', 'twitter:image'):
        for m in re.findall(rf'(?:property|name)=["\x27]{prop}["\x27] content=["\x27]([^"\x27]*)["\x27]', text):
            if re.fullmatch(r'https?://[^/]+/?', m.strip()):
                social_bad.append(f'{rel}: {prop} points at the site root')
if social_bad:
    bad('social tags match the page kind', '\n'.join(f'  {b}' for b in social_bad))
else:
    ok('social tags match the page kind')

# R12 structural tags balance on every page: a stray closer from a
#    conditional wrapper (or a missing one) shows up as open/close mismatch
STRUCT_TAGS = ('div', 'ul', 'ol', 'dl', 'nav', 'footer', 'header', 'main',
               'section', 'article', 'figure', 'figcaption', 'button', 'a',
               'p', 'li', 'span', 'table', 'thead', 'tbody', 'tfoot', 'tr',
               'td', 'th', 'form', 'label', 'textarea', 'select', 'blockquote',
               'pre', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'dt', 'dd')
bal_bad = []
for t in htmls:
    text = t.read_text(errors='ignore')
    if 'http-equiv="refresh"' in text:
        continue
    rel = t.relative_to(pub)
    clean = re.sub(r'<!--.*?-->', '', text, flags=re.S)
    clean = re.sub(r'<(script|style)\b.*?</\1>', '', clean, flags=re.S | re.I)
    for tag in STRUCT_TAGS:
        opens = len(re.findall(rf'<{tag}[\s>]', clean, re.I))
        closes = len(re.findall(rf'</{tag}\s*>', clean, re.I))
        if opens != closes:
            bal_bad.append(f'{rel}: <{tag}> {opens} opens vs {closes} closes')
if bal_bad:
    bad('structural tags balance', '\n'.join(f'  {b}' for b in bal_bad))
else:
    ok('structural tags balance')

# R11 ad units ship with authorization: any data-ad-client in the markup
#    requires static/ads.txt in the output naming the same publisher ID
ad_clients = set()
for t in htmls:
    text = t.read_text(errors='ignore')
    for m in re.findall(r'data-ad-client=["\x27]([^"\x27]*)["\x27]', text):
        ad_clients.add(m)
if ad_clients:
    ads_txt = pub / 'ads.txt'
    if not ads_txt.is_file():
        bad('ads.txt names every advertised publisher', '  ads.txt missing')
    else:
        body = ads_txt.read_text(errors='ignore')
        missing = []
        for c in sorted(ad_clients):
            digits = re.sub(r'\D', '', c)
            if not digits or not re.search(rf'(?<!\d){digits}(?!\d)', body):
                missing.append(c)
        if missing:
            bad('ads.txt names every advertised publisher',
                '\n'.join(f'  {c} not in ads.txt' for c in missing))
        else:
            ok('ads.txt names every advertised publisher')
else:
    ok('ads.txt names every advertised publisher')

# R13 articles carry bodies: an article page (og:type=article) whose content
#    block holds zero words is a migration accident, not a page
# Void tags fire handle_starttag but never handle_endtag. Counting them in the
# depth counter leaks it past the content block, so the footer would be counted
# as article body and this rule would never fire on any page with an image.
VOID = frozenset(("area", "base", "br", "col", "embed", "hr", "img", "input",
                  "link", "meta", "param", "source", "track", "wbr"))


class BodyWords(HTMLParser):
    def __init__(self):
        super().__init__()
        self.depth = 0
        self.words = 0

    def handle_starttag(self, tag, attrs):
        if tag in VOID:
            return
        if self.depth:
            self.depth += 1
        elif tag == 'div' and any(k == 'class' and 'article__content' in (v or '')
                                  for k, v in attrs):
            self.depth = 1

    def handle_endtag(self, tag):
        if tag not in VOID and self.depth:
            self.depth -= 1

    def handle_data(self, data):
        if self.depth:
            self.words += len(data.split())


thin = []
for t in htmls:
    text = t.read_text(errors='ignore')
    if 'http-equiv="refresh"' in text:
        continue
    og = re.search(r'property=["\x27]og:type["\x27] content=["\x27](\w+)["\x27]', text)
    if not og or og.group(1) != 'article':
        continue
    parser = BodyWords()
    try:
        parser.feed(text)
    except Exception:
        continue
    if parser.words == 0:
        thin.append(f'{t.relative_to(pub)}: article has no body text')
if thin:
    bad('article pages carry bodies', '\n'.join(f'  {b}' for b in thin))
else:
    ok('article pages carry bodies')

# R14 robots declares the sitemap crawlers and auditors look for
robots = pub / 'robots.txt'
if robots.is_file() and 'Sitemap:' in robots.read_text(errors='ignore'):
    ok('robots declares the sitemap')
else:
    bad('robots declares the sitemap', '  no Sitemap: line in robots.txt')

# R15 search ships as a pair: a header button without its index (the site
#    needs [outputs] home = ["HTML", "RSS", "JSON"]) is a silent dead button
home = (pub / 'index.html').read_text(errors='ignore') if (pub / 'index.html').is_file() else ''
if 'data-search-toggle' in home and not (pub / 'index.json').is_file():
    bad('search button ships with its index', '  enableSearch is on but no index.json: add "JSON" to [outputs] home')
elif 'data-search-toggle' not in home and (pub / 'index.json').is_file():
    bad('search button ships with its index', '  index.json ships with no button: set enableSearch = true or drop "JSON" from [outputs] home')
else:
    ok('search button ships with its index')

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

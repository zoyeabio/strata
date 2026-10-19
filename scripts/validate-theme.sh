#!/usr/bin/env bash
# Validate the theme's own build output.
#
# Usage: ./scripts/validate-theme.sh
#
# Builds test/fixture in minified production mode twice: without drafts the build
# must be silent and the output must satisfy scripts/check-build.sh; with
# drafts the known missing-image page must fail the build (a silent skip
# in production is how dead references survive for years).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The gate scripts lean on the standard library's tomllib (3.11+) to resolve
# the same config pair Hugo merges. A system python3 below that dies with a
# traceback mid-script, so name the requirement before any build output.
if ! python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)'; then
  printf 'ERROR: python3 >= 3.11 is required (stdlib tomllib)\n' >&2
  exit 2
fi
# Hugo 0.161.0+ runs the TailwindCSS CLI through node, so its npm install has
# to be on PATH before any build below can transform the stylesheet.
if [ -d "$ROOT/node_modules/.bin" ]; then
  PATH="$ROOT/node_modules/.bin:$PATH"
  export PATH
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAILURES=0

pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }

if ! hugo --source "$ROOT/test/fixture" --environment production --minify \
    --destination "$WORK/public" 2>"$WORK/build.stderr" >/dev/null; then
  fail 'fixture builds in production mode'
  cat "$WORK/build.stderr" >&2
  exit 1
fi
pass 'fixture builds a minified production artifact'

if [ -s "$WORK/build.stderr" ]; then
  fail 'production build is silent'
  cat "$WORK/build.stderr" >&2
else
  pass 'production build is silent'
fi

# The theme's defaults live in its config/_default/params.toml. Assert every key
# a template reads is defined there, so a site always overrides a key rather than
# a template fallback deciding for it. Read the file directly rather than going
# through `hugo config`, which marshals with omitempty and would silently hide
# every default that happens to be false, "" or [].
if cfg_out=$(cd "$ROOT" && python3 - <<'PY'
import re
import sys
import tomllib
from pathlib import Path

with Path("config/_default/params.toml").open("rb") as fh:
    theme = tomllib.load(fh)
theme_params = {k.lower(): v for k, v in theme.items()}

# Absent by design: an empty slice is truthy in Go templates and
# _default/single.html reads it through `with`, so shipping one would flip
# "every single is an article" into "none is".
if "mainSections" in theme_params:
    print("FAIL params.mainSections must stay absent from the theme",
          file=sys.stderr)
    sys.exit(1)

read = set()
for page in Path("layouts").rglob("*"):
    if page.is_file():
        read |= set(re.findall(r"(?:site|\.Site)\.Params\.(\w+)", page.read_text()))

missing = sorted(k for k in read - {"mainSections"}
                 if k.lower() not in theme_params)
if missing:
    print("FAIL undefined in config/_default/params.toml: %s"
          % ", ".join(missing), file=sys.stderr)
    sys.exit(1)
print("%d params defined, all %d read by templates covered"
      % (len(theme_params), len(read - {"mainSections"})))
PY
); then
  pass "every key a template reads is defined in the theme's params.toml ($cfg_out)"
else
  fail 'every key a template reads is defined in the theme params.toml'
fi

# The image pipeline and build thresholds must also reach a consuming site, not
# just sit in a file: prove they merge underneath a site's own config. `hugo
# config` is safe here because these defaults are all non-zero.
if cfg_out=$(cd "$ROOT" && python3 - <<'PY'
import json
import subprocess
import sys

cfg = json.loads(subprocess.check_output([
    "hugo", "--source", "test/fixture", "--format", "json", "config",
], text=True))
params = {k.lower(): v for k, v in cfg.get("params", {}).items()}

def absent(path):
    node = params
    for key in path:
        node = node.get(key.lower(), {}) if isinstance(node, dict) else {}
    return not node

missing = [
    "params.%s" % ".".join(p)
    for p in (("image", "ladder"), ("image", "quality"), ("image", "caps"),
               ("image", "og"), ("build", "pageimageskb"), ("build", "minwidth"),
               ("build", "maxfiles"), ("build", "maxsourcekb"))
    if absent(p)
]
if missing:
    print("FAIL missing: %s" % ", ".join(missing), file=sys.stderr)
    sys.exit(1)
print("params.image and params.build merge into the site")
PY
); then
  pass "the theme's config reaches a consuming site ($cfg_out)"
else
  fail 'the theme config reaches a consuming site'
fi

if "$ROOT/scripts/check-build.sh" "$WORK/public" --mode theme --site "$ROOT/test/fixture"; then
  pass 'check-build theme mode'
else
  fail 'check-build theme mode'
fi

# A cap with no headroom must fail the rule set: the hosting platform refuses
# a deploy over its file ceiling, so check-build carries the same number.
mkdir -p "$WORK/tiny-files/config/_default"
printf '[params]\n[params.build]\nmaxfiles = 1\n' > "$WORK/tiny-files/config/_default/params.toml"
if "$ROOT/scripts/check-build.sh" "$WORK/public" --mode theme --site "$WORK/tiny-files" \
    >"$WORK/files-cap.out" 2>&1; then
  fail 'check-build rejects a build over its file-count limit'
elif grep -q 'within 1 files' "$WORK/files-cap.out"; then
  pass 'check-build rejects a build over its file-count limit'
else
  fail 'the file-count failure names the limit'
  cat "$WORK/files-cap.out" >&2
fi

# R11 parses ads.txt records instead of substring-matching the file, so a
# commented-out stub line ("# google.com, pub-…", exactly what new-site.sh
# scaffolds) cannot pass as an authorization. Tamper the real fixture output
# and the gate must name the missing record.
if sed 's/^google\.com/# google.com/' "$WORK/public/ads.txt" >"$WORK/ads-commented.txt"; then
  cp "$WORK/public/ads.txt" "$WORK/ads-original.txt"
  cp "$WORK/ads-commented.txt" "$WORK/public/ads.txt"
  if "$ROOT/scripts/check-build.sh" "$WORK/public" --mode theme --site "$ROOT/test/fixture" \
      >"$WORK/ads-stub.out" 2>&1; then
    fail 'a commented-out ads.txt record does not authorize the publisher'
  elif grep -q 'not authorized by any ads.txt record' "$WORK/ads-stub.out"; then
    pass 'a commented-out ads.txt record does not authorize the publisher'
  else
    fail 'the ads.txt failure names the missing record'
    cat "$WORK/ads-stub.out" >&2
  fi
  cp "$WORK/ads-original.txt" "$WORK/public/ads.txt"
else
  fail 'the fixture public output carries ads.txt to tamper'
fi

# The CSP check anchors the policy line itself. A commented-out line or a
# Content-Security-Policy-Report-Only stance states an intent to relax the
# policy without shipping a header that actually blocks the loader, so
# neither may satisfy head.html. This scratch site must fail twice — once
# where only a Report-Only line allows the origin (the exact shape a
# "Report-Only first, then enforce" walkthrough produces) and once where the
# allow line is a comment — and must build with the real header present.
ADS_SCRATCH="$WORK/ads-scratch"
mkdir -p "$ADS_SCRATCH/config/_default" "$ADS_SCRATCH/content" "$ADS_SCRATCH/static"
cat >"$ADS_SCRATCH/go.mod" <<EOF
module example.com/ads-scratch

go 1.22

require github.com/zoyeabio/strata v0.1.1

replace github.com/zoyeabio/strata => $ROOT
EOF
cat >"$ADS_SCRATCH/config/_default/hugo.toml" <<'TOML'
[module]
  proxy = "direct"
  [[module.imports]]
    path = "github.com/zoyeabio/strata"
[module.hugoVersion]
  extended = true
  min = "0.161.0"

[[module.mounts]]
  source = 'assets'
  target = 'assets'

[[module.mounts]]
  disableWatch = true
  source = 'hugo_stats.json'
  target = 'assets/notwatching/hugo_stats.json'

[build.buildStats]
  enable = true

[[build.cachebusters]]
  source = 'assets/notwatching/hugo_stats\.json'
  target = 'css'

[security.node]
  [security.node.permissions]
    allowAddons = ['tailwindcss']
    allowChildProcess = ['tailwindcss']
    allowRead = ['.']
    allowWorker = ['tailwindcss']
    allowWrite = []
    disable = false

[security.exec]
  allow = ['go', 'node', 'tailwindcss']
TOML
cat >"$ADS_SCRATCH/config/_default/params.toml" <<'TOML'
[ads]
  client = "ca-pub-0000000000000000"
  consent = "none"
TOML
cat >"$ADS_SCRATCH/content/ads-page.md" <<'MD'
---
title: "Ads page"
date: 2026-01-05
---

{{< ads slot="1234567890" >}}
MD
mkdir -p "$ADS_SCRATCH/layouts/partials"
cat >"$ADS_SCRATCH/layouts/partials/cookie-consent.html" <<'HTML'
<div data-cookie-consent role="region" aria-label="Cookie consent">
  <p>Cookies: analytics and ads, your choice in this banner.</p>
</div>
HTML
scratch_hugo() { # scratch_hugo — build the scratch site; returns hugo's status
  HUGO_CACHEDIR="$WORK/scratch-cache" hugo --source "$ADS_SCRATCH" \
    --environment production --minify --destination "$ADS_SCRATCH-public" \
    >"$WORK/scratch-build.out" 2>"$WORK/scratch-build.stderr"
}

cat >"$ADS_SCRATCH/static/_headers" <<'EOF'
Content-Security-Policy: default-src 'self'; script-src 'self' https://pagead2.googlesyndication.com; object-src 'none'
EOF
if scratch_hugo \
  && grep -q 'adsbygoogle.js?client=' "$ADS_SCRATCH-public/ads-page/index.html"; then
  pass 'a real CSP header line allows the loader through'
else
  fail 'a real CSP header line allows the loader through'
  cat "$WORK/scratch-build.stderr" >&2
fi

cat >"$ADS_SCRATCH/static/_headers" <<'EOF'
Content-Security-Policy: default-src 'self'; script-src 'self'; object-src 'none'

Content-Security-Policy-Report-Only: script-src 'self' https://pagead2.googlesyndication.com
EOF
if scratch_hugo; then
  fail 'a Report-Only CSP cannot authorize the loader'
elif grep -q 'no Content-Security-Policy script-src allows pagead2' \
    "$WORK/scratch-build.stderr"; then
  pass 'a Report-Only CSP cannot authorize the loader'
else
  fail 'the Report-Only failure names the missing policy'
  cat "$WORK/scratch-build.stderr" >&2
fi

cat >"$ADS_SCRATCH/static/_headers" <<'EOF'
# uncomment when ready: Content-Security-Policy: script-src 'self' https://pagead2.googlesyndication.com
EOF
if scratch_hugo; then
  fail 'a commented-out CSP line cannot authorize the loader'
elif grep -q 'no Content-Security-Policy script-src allows pagead2' \
    "$WORK/scratch-build.stderr"; then
  pass 'a commented-out CSP line cannot authorize the loader'
else
  fail 'the commented-policy failure names the missing policy'
  cat "$WORK/scratch-build.stderr" >&2
fi

# A valid policy again for the shape tests below, which expect the site to
# build: the copied block is the working one from docs/security.md.
cat >"$ADS_SCRATCH/static/_headers" <<'EOF'
Content-Security-Policy: default-src 'self'; script-src 'self' https://pagead2.googlesyndication.com; object-src 'none'
EOF
# The ads shortcode contracts on shape: a slot that is not the dashboard's
# numeric ID and a client that is not a ca-pub-… publisher ID fail the build
# instead of reaching Google as a garbage loader URL.
cp "$ADS_SCRATCH/content/ads-page.md" "$WORK/ads-page-original.md"
sed 's/slot="1234567890"/slot="12-sydney"/' "$ADS_SCRATCH/content/ads-page.md" \
  >"$WORK/ads-page-badslot.md"
mv "$WORK/ads-page-badslot.md" "$ADS_SCRATCH/content/ads-page.md"
if scratch_hugo; then
  fail 'a non-numeric ad slot fails the build'
elif grep -q 'slot .* is not the numeric ID' "$WORK/scratch-build.stderr"; then
  pass 'a non-numeric ad slot fails the build'
else
  fail 'the ad slot failure names the bad value'
  cat "$WORK/scratch-build.stderr" >&2
fi
cp "$WORK/ads-page-original.md" "$ADS_SCRATCH/content/ads-page.md"

cp "$ADS_SCRATCH/config/_default/params.toml" "$WORK/params-original.toml"
printf '[ads]\n  client = "pub-0000000000000000"\n  consent = "none"\n' \
  >"$ADS_SCRATCH/config/_default/params.toml"
if scratch_hugo; then
  fail 'a malformed publisher ID fails the build'
elif grep -q 'does not look like a ca-pub-' "$WORK/scratch-build.stderr"; then
  pass 'a malformed publisher ID fails the build'
else
  fail 'the publisher ID failure names the bad value'
  cat "$WORK/scratch-build.stderr" >&2
fi
cp "$WORK/params-original.toml" "$ADS_SCRATCH/config/_default/params.toml"

# [ads] consent "gated": head ships no loader and the push copy carries the
# posture. In both modes the CSP check stays in force, because the loader
# leaves at grant time; the _headers scratch file already allows the origin.
printf '[ads]\n  client = "ca-pub-0000000000000000"\n  consent = "gated"\n' \
  >"$ADS_SCRATCH/config/_default/params.toml"
if scratch_hugo \
   && ! grep -qE 'adsbygoogle\.js\?client=' "$ADS_SCRATCH-public/ads-page/index.html" \
   && grep -qE 'data-ads-consent=.?gated' "$ADS_SCRATCH-public/ads-page/index.html" \
   && grep -qE '<ins class=.?adsbygoogle' "$ADS_SCRATCH-public/ads-page/index.html"; then
  pass 'gated consent keeps the loader out of head and marks the push copy'
else
  fail 'gated consent keeps the loader out of head and marks the push copy'
  cat "$WORK/scratch-build.stderr" >&2
fi

printf '[ads]\n  client = "ca-pub-0000000000000000"\n  consent = "certified"\n' \
  >"$ADS_SCRATCH/config/_default/params.toml"
if scratch_hugo; then
  fail 'an unlisted consent value fails the build'
elif grep -q 'is not one of "none" or "gated"' "$WORK/scratch-build.stderr"; then
  pass 'an unlisted consent value fails the build'
else
  fail 'the consent failure names the accepted values'
  cat "$WORK/scratch-build.stderr" >&2
fi
cp "$WORK/params-original.toml" "$ADS_SCRATCH/config/_default/params.toml"

# [ads] auto hands placement to Google: no shortcode anywhere, the loader
# ships site-wide, and hugo itself never asks why — the authorization
# bookwork (ads.txt, notices) stays with check-build, proven against the
# fixture output right below.
mv "$ADS_SCRATCH/content/ads-page.md" "$WORK/ads-page-stowed.md"
printf '[ads]\n  client = "ca-pub-0000000000000000"\n  auto = true\n  consent = "none"\n' \
  >"$ADS_SCRATCH/config/_default/params.toml"
if scratch_hugo \
   && grep -qE 'adsbygoogle\.js\?client=ca-pub-0000000000000000' \
     "$ADS_SCRATCH-public/index.html" \
   && ! grep -qE '<ins class=.?adsbygoogle' "$ADS_SCRATCH-public/index.html"; then
  pass 'auto ships the loader on pages that never held a unit'
else
  fail 'auto ships the loader on pages that never held a unit'
  cat "$WORK/scratch-build.stderr" >&2
fi

# auto in gated consent mode with no shortcode anywhere: the fingerprinted
# dispatcher js/ads.js only rolls inside shortcode copies, so the wait for
# the consent answer would ride nothing and the site would show no ads
# without saying why — head.html fails such a build instead.
printf '[ads]\n  client = "ca-pub-0000000000000000"\n  consent = "gated"\n  auto = true\n' \
  >"$ADS_SCRATCH/config/_default/params.toml"
if scratch_hugo; then
  fail 'gated auto with no placed unit carrier fails the build'
elif grep -q 'would mean silently no ads' "$WORK/scratch-build.stderr"; then
  pass 'gated auto with no placed unit carrier fails the build'
else
  fail 'the carrier failure names the fix'
  cat "$WORK/scratch-build.stderr" >&2
fi
printf '[ads]\n  client = "ca-pub-0000000000000000"\n  auto = true\n  consent = "none"\n' \
  >"$ADS_SCRATCH/config/_default/params.toml"
mv "$WORK/ads-page-stowed.md" "$ADS_SCRATCH/content/ads-page.md"

# check-build keys R11 off the loader URL, not only units: a loader with a
# foreign publisher pasted into otherwise clean pages has the site's
# ads.txt as its only counter-record, and the gate names the loader's
# client. This is the [ads] auto evidence path — no data-ad-client exists.
cp "$WORK/public/index.html" "$WORK/index-original.html"
printf '<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-9999999999999999" crossorigin="anonymous"></script>\n' \
  >>"$WORK/public/index.html"
if "$ROOT/scripts/check-build.sh" "$WORK/public" --mode theme --site "$ROOT/test/fixture" \
    >"$WORK/loader-forged.out" 2>&1; then
  fail 'a loader URL counts as authorization and gets checked'
elif grep -q 'ca-pub-9999999999999999 not authorized by any ads.txt record' \
    "$WORK/loader-forged.out"; then
  pass 'a loader URL counts as authorization and gets checked'
else
  fail 'the loader authorization failure names the loader client'
  cat "$WORK/loader-forged.out" >&2
fi
cp "$WORK/index-original.html" "$WORK/public/index.html"

printf '[ads]\n  client = "ca-pub-0000000000000000"\n  consent = "none"\n' \
  >"$ADS_SCRATCH/config/_default/params.toml"
if scratch_hugo \
   && ! grep -qE 'adsbygoogle\.js\?client=' "$ADS_SCRATCH-public/index.html" \
   && grep -qE 'data-ad-client=.?ca-pub-0000000000000000' \
     "$ADS_SCRATCH-public/ads-page/index.html"; then
  pass 'no shortcode and no auto keeps the loader off untouched pages'
else
  fail 'no shortcode and no auto keeps the loader off untouched pages'
  cat "$WORK/scratch-build.stderr" >&2
fi
cp "$WORK/params-original.toml" "$ADS_SCRATCH/config/_default/params.toml"

# R17: ads authorized implies complete legal notices. Two tamer paths
# against the real fixture output — a placeholder left visible in the
# privacy text, and the cookies page deleted outright — must both fail,
# naming the page and the placeholder.
cp "$WORK/public/privacy-policy/index.html" "$WORK/privacy-original.html"
printf '<p>Contact us at [TBD: the postmaster address].</p>\n' \
  >"$WORK/public/privacy-policy/index.html"
if "$ROOT/scripts/check-build.sh" "$WORK/public" --mode theme --site "$ROOT/test/fixture" \
    >"$WORK/legal-tbd.out" 2>&1; then
  fail 'a [TBD] left in the published privacy notice fails the gate'
elif grep -q 'is still in the published notice' "$WORK/legal-tbd.out" \
  && grep -q 'privacy-policy' "$WORK/legal-tbd.out"; then
  pass 'a [TBD] left in the published privacy notice fails the gate'
else
  fail 'the placeholder failure names the page and the text'
  cat "$WORK/legal-tbd.out" >&2
fi
cp "$WORK/privacy-original.html" "$WORK/public/privacy-policy/index.html"

mv "$WORK/public/cookies" "$WORK/cookies-original-dir"
if "$ROOT/scripts/check-build.sh" "$WORK/public" --mode theme --site "$ROOT/test/fixture" \
    >"$WORK/legal-missing.out" 2>&1; then
  fail 'a deleted cookies page fails the gate'
elif grep -q '/cookies/ missing' "$WORK/legal-missing.out"; then
  pass 'a deleted cookies page fails the gate'
else
  fail 'the missing-notice failure names the page'
  cat "$WORK/legal-missing.out" >&2
fi
mv "$WORK/cookies-original-dir" "$WORK/public/cookies"

# every share URL template must consume both printf arguments — the permalink
# and the title. Hugo's printf does not error on a missing verb, it appends
# %!N(EXTRA string=...) to the URL, so a site author who writes ?url=%s
# ships a working-looking button that produces a dead link. This catches it at
# build time rather than at click time.
if sharing_out=$(cd "$ROOT" && python3 - <<'PY'
import json
import pathlib
import re
import sys

data = json.loads((pathlib.Path("data/sharing.json")).read_text())
bad = []
for name, svc in sorted(data.items()):
    if not isinstance(svc, dict) or "url" not in svc:
        bad.append("%s: no url" % name)
        continue
    verbs = re.findall(r'%\[\d+\][a-z]|%[a-z]', svc["url"])
    if len(verbs) != 2:
        bad.append("%s: %d verb(s) %s, want 2 — %r"
                   % (name, len(verbs), verbs, svc["url"]))
if bad:
    for line in bad:
        print("FAIL " + line, file=sys.stderr)
    sys.exit(1)
print("%d share templates, 2 verbs each" % len(data))
PY
); then
  pass "share URL templates consume both arguments ($sharing_out)"
else
  fail 'share URL templates consume both arguments'
fi

# the draft missing.md declares an unresolvable featureimage on purpose
if hugo --source "$ROOT/test/fixture" --environment production --buildDrafts --minify \
    --destination "$WORK/public-drafts" 2>"$WORK/drafts.stderr" >/dev/null; then
  fail 'a missing image must fail the production build'
elif grep -q 'image not found' "$WORK/drafts.stderr"; then
  pass 'a missing image fails the production build'
else
  fail 'the production failure names the missing image'
  cat "$WORK/drafts.stderr" >&2
fi

# the draft map-missing.md calls the map shortcode without its required src
if grep -q 'map shortcode: missing required src' "$WORK/drafts.stderr"; then
  pass 'a srcless map fails the production build'
else
  fail 'the production failure names the srcless map'
  cat "$WORK/drafts.stderr" >&2
fi

mkdir -p "$WORK/image-site"
if "$ROOT/scripts/place-image.sh" --section journal --post undersized \
    --file "$ROOT/test/fixture/assets/images/section-a/inline.png" \
    --role illustration --site "$WORK/image-site" \
    >"$WORK/place-small.out" 2>&1; then
  fail 'place-image rejects an undersized illustration source'
elif grep -q 'at least 1600px wide' "$WORK/place-small.out"; then
  pass 'place-image rejects an undersized illustration source'
else
  fail 'the illustration size failure names the 1600px minimum'
  cat "$WORK/place-small.out" >&2
fi

if "$ROOT/scripts/place-image.sh" --section journal --post production \
    --file "$ROOT/test/fixture/assets/images/section-a/photo-flat.png" \
    --role illustration --site "$WORK/image-site" \
    >"$WORK/place-large.out" 2>&1 \
    && [ -f "$WORK/image-site/assets/images/journal/production/photo-flat.png" ]; then
  pass 'place-image accepts a production-size illustration source'
else
  fail 'place-image accepts a production-size illustration source'
  cat "$WORK/place-large.out" >&2
fi

# The source cap binds before anything is copied: over the limit the file
# must not enter the site's assets tree.
mkdir -p "$WORK/image-site/config/_default"
printf '[params]\n[params.build]\nmaxsourcekb = 1\n' > "$WORK/image-site/config/_default/params.toml"
if "$ROOT/scripts/place-image.sh" --section journal --post over-cap \
    --file "$ROOT/test/fixture/assets/images/section-a/photo-flat.png" \
    --role illustration --site "$WORK/image-site" \
    >"$WORK/place-overcap.out" 2>&1; then
  fail 'place-image rejects an over-cap source before copying'
elif grep -q 'the cap is 1KB' "$WORK/place-overcap.out" \
    && [ ! -f "$WORK/image-site/assets/images/journal/over-cap/photo-flat.png" ]; then
  pass 'place-image rejects an over-cap source before copying'
else
  fail 'the source-size failure names the cap'
  cat "$WORK/place-overcap.out" >&2
fi

# The theme's own example site is the content contract: it must pass the
# front matter lint the consuming sites are held to.
if "$ROOT/scripts/validate-content.sh" "$ROOT/exampleSite"
then
  pass 'exampleSite front matter is complete'
else
  fail 'exampleSite front matter is complete'
fi

# and it must still demonstrate the theme's public surface. test/fixture
# asserts mechanically; exampleSite is the other kind of test, the one a
# reader sees. A new shortcode or a new site hook has to ship with a live
# example and a working implementation to copy from, or this fails.
if "$ROOT/scripts/validate-example.sh" "$ROOT"
then
  pass 'exampleSite demonstrates the theme public surface'
else
  fail 'exampleSite demonstrates the theme public surface'
fi

# A banner that names nothing is not a notice. check-build catches an empty
# href, not a link whose target is missing, so the pair is pinned here: the
# pages exist and the banner points at them through relLangURL, so a
# language-prefixed site keeps its prefixes.
if grep -q 'href="{{ "/cookies/" | relLangURL }}"' "$ROOT/exampleSite/layouts/partials/cookie-consent.html" \
   && grep -q 'href="{{ "/privacy-policy/" | relLangURL }}"' "$ROOT/exampleSite/layouts/partials/cookie-consent.html" \
   && ( for p in cookies privacy-policy terms; do
        [ -f "$ROOT/exampleSite/content/$p.md" ] || exit 1
      done )
then
  pass 'the consent banner points at published notices'
else
  fail 'the consent banner points at published notices'
fi

# Summary is a documented description fallback and Hugo exposes a top-level
# summary through .Params. Pin that spelling so the lint cannot accidentally
# require the nested params form while the templates accept both.
mkdir -p "$WORK/summary-site/config/_default" "$WORK/summary-site/content/posts"
cat >"$WORK/summary-site/config/_default/hugo.toml" <<'TOML'
[taxonomies]
  tag = "tags"
TOML
cat >"$WORK/summary-site/content/posts/example.md" <<'MD'
---
title: "Summary-only example"
date: 2026-01-05
params:
  summary: "A reader-facing standfirst that also supplies the metadata fallback."
  keywords: ["example"]
---
Body.
MD
if "$ROOT/scripts/validate-content.sh" "$WORK/summary-site" >"$WORK/summary.out" 2>&1; then
  pass 'nested summary and keywords satisfy the dated-page metadata contract'
else
  fail 'nested summary and keywords satisfy the dated-page metadata contract'
  cat "$WORK/summary.out" >&2
fi

# A lint that only ever passes is a comment, not a gate. A scratch site carries
# an unknown key and a lastmod before the date — the pair that publishes
# dateModified before datePublished into JSON-LD with every gate green.
mkdir -p "$WORK/bad-site/config/_default" "$WORK/bad-site/content/posts"
cat >"$WORK/bad-site/config/_default/hugo.toml" <<'TOML'
[taxonomies]
  tag = "tags"
TOML
cat >"$WORK/bad-site/content/posts/example.md" <<'MD'
---
title: "Example"
date: 2026-01-05
lastmod: 2025-01-01
params:
  typo: true
---
MD
if "$ROOT/scripts/validate-content.sh" "$WORK/bad-site" >"$WORK/content.out" 2>&1; then
  fail 'the content lint reports an unknown key and an inverted date'
else
  if grep -q 'unknown front matter key' "$WORK/content.out" \
    && grep -q 'lastmod is not before date' "$WORK/content.out"; then
    pass 'the content lint reports an unknown key and an inverted date'
  else
    fail 'the content lint failure names the bad keys'
    cat "$WORK/content.out" >&2
  fi
fi

if "$ROOT/scripts/new-site.sh" --name "Fixture Site" --slug fixture-site \
    --domain fixture.example --out "$WORK/scaffold" --sections "science" \
    >"$WORK/scaffold.out" 2>"$WORK/scaffold.stderr" \
    && [ ! -s "$WORK/scaffold.stderr" ] \
    && python3 - "$WORK/scaffold" <<'PY'
import pathlib
import sys
import tomllib

root = pathlib.Path(sys.argv[1])
with (root / "config/_default/hugo.toml").open("rb") as fh:
    config = tomllib.load(fh)
assert config["cascade"][0]["build"]["publishResources"] is False

front = (root / "archetypes/default/index.md").read_text()
keys = ("title:", "description:", "summary:", "keywords:", "author:",
        "date:", "lastmod:", "tags:", "featureimage:",
        "featureimagealt:", "showHero:", "showSummary:", "weight:")
assert all(key in front for key in keys)

workflow = (root / ".github/workflows/validate.yml").read_text()
assert "repository: zoyeabio/strata" in workflow
assert "path: ../strata" in workflow
assert "validate-site.sh" in workflow
require = next(line for line in (root / "go.mod").read_text().splitlines()
               if line.startswith("require github.com/zoyeabio/strata"))
assert f"ref: {require.split()[-1]}" in workflow
PY
then
  pass 'new sites suppress unused bundle originals, carry the article metadata scaffold and a validating CI workflow'
else
  fail 'new sites suppress unused bundle originals, carry the article metadata scaffold and a validating CI workflow'
  cat "$WORK/scaffold.out" "$WORK/scaffold.stderr" >&2
fi

# Config is a merge, not a last-file-wins scan. An empty production overlay
# must not erase the tag/series contract declared in the default config.
mkdir -p "$WORK/scaffold/config/production"
cat >"$WORK/scaffold/config/production/taxonomies.toml" <<'TOML'
[taxonomies]
TOML
if "$ROOT/scripts/validate-site.sh" "$WORK/scaffold" \
    >"$WORK/scaffold-merged.out" 2>"$WORK/scaffold-merged.stderr" \
    && grep -q 'site enables tags and series' "$WORK/scaffold-merged.out"; then
  pass 'split taxonomy config is merged before its contract is checked'
else
  fail 'split taxonomy config is merged before its contract is checked'
  cat "$WORK/scaffold-merged.out" "$WORK/scaffold-merged.stderr" >&2
fi

# A taxonomy-free consumer is a supported production shape. Render one through
# the complete site gate and inspect the resulting artifact, so GetTerms calls
# cannot regress into empty taxonomy markup or dead URLs unnoticed.
rm "$WORK/scaffold/config/production/taxonomies.toml"
python3 - "$WORK/scaffold/config/_default/hugo.toml" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
text = text.replace('[taxonomies]\n  tag = "tags"\n  series = "series"', '[taxonomies]')
path.write_text(text)
PY
mkdir -p "$WORK/scaffold/content/science/lean"
cat >"$WORK/scaffold/content/science/lean/index.md" <<'MD'
---
title: "Lean article"
description: "A production article rendered without taxonomy pages."
summary: "A production article rendered without taxonomy pages."
keywords: ["lean"]
date: 2026-01-05
---
The article remains complete without tags or series.
MD
if "$ROOT/scripts/validate-site.sh" "$WORK/scaffold" \
    >"$WORK/scaffold-lean.out" 2>"$WORK/scaffold-lean.stderr" \
    && grep -q 'site explicitly disables taxonomies with an empty \[taxonomies\] table' \
      "$WORK/scaffold-lean.out" \
    && HUGO_CACHEDIR="$WORK/lean-cache" hugo --source "$WORK/scaffold" \
      --environment production --minify --destination "$WORK/lean-public" \
      >"$WORK/lean-build.out" 2>"$WORK/lean-build.stderr" \
    && [ ! -e "$WORK/lean-public/tags" ] \
    && [ ! -e "$WORK/lean-public/series" ] \
    && [ -s "$WORK/lean-public/science/lean/index.html" ] \
    && ! grep -Eq "article__tag|<nav[^>]*class=[\"']?series([\"']|[[:space:]>])" \
      "$WORK/lean-public/science/lean/index.html"; then
  pass 'a taxonomy-free site builds without taxonomy output or empty term markup'
else
  fail 'a taxonomy-free site builds without taxonomy output or empty term markup'
  cat "$WORK/scaffold-lean.out" "$WORK/scaffold-lean.stderr" \
    "$WORK/lean-build.out" "$WORK/lean-build.stderr" >&2
fi

# Ads on a FRESH scaffold must bite through every gate, not only tampered
# fixture output: the un-picked consent mode is a head build error, and once
# a mode is picked the drafted notice stubs and the comment-only ads.txt
# stub fail check-build — the default state a new publisher hits.
printf '[ads]\n  client = "ca-pub-0000000000000000"\n  auto = true\n' \
  >"$WORK/scaffold/config/_default/params.toml"
if "$ROOT/scripts/validate-site.sh" "$WORK/scaffold" \
    >"$WORK/scaffold-ads-1.out" 2>"$WORK/scaffold-ads-1.err"; then
  fail 'an un-picked consent mode fails the scaffold build'
elif grep -q 'consent must be picked explicitly' \
    "$WORK/scaffold-ads-1.out" "$WORK/scaffold-ads-1.err"; then
  pass 'an un-picked consent mode fails the scaffold build'
else
  fail 'the consent-pick failure names the two values'
  cat "$WORK/scaffold-ads-1.out" "$WORK/scaffold-ads-1.err" >&2
fi

cat >"$WORK/scaffold/static/_headers" <<'EOF'
Content-Security-Policy: default-src 'self'; script-src 'self' https://pagead2.googlesyndication.com; object-src 'none'
EOF
printf '[ads]\n  client = "ca-pub-0000000000000000"\n  auto = true\n  consent = "none"\n' \
  >"$WORK/scaffold/config/_default/params.toml"
if "$ROOT/scripts/validate-site.sh" "$WORK/scaffold" \
    >"$WORK/scaffold-ads-2.out" 2>"$WORK/scaffold-ads-2.err"; then
  fail 'a scaffold with drafted notices and a stub ads.txt fails the gate'
elif grep -q 'publishes no notice there' "$WORK/scaffold-ads-2.out" \
   && grep -q 'not authorized by any ads.txt record' "$WORK/scaffold-ads-2.out"; then
  pass 'a scaffold with drafted notices and a stub ads.txt fails the gate'
else
  fail 'the scaffold enable-ads failure names both stubs'
  cat "$WORK/scaffold-ads-2.out" "$WORK/scaffold-ads-2.err" >&2
fi
rm "$WORK/scaffold/config/_default/params.toml"

# R11 field checks behind the loader path too: a record naming the right
# publisher under a foreign seller domain is not an Google authorization;
# and a garbage certification-authority field, when present, is malformed.
cp "$WORK/public/ads.txt" "$WORK/ads-original.txt"
printf 'not-google.example, pub-0000000000000000, DIRECT, wrong-authority\n' \
  >"$WORK/public/ads.txt"
if "$ROOT/scripts/check-build.sh" "$WORK/public" --mode theme --site "$ROOT/test/fixture" \
    >"$WORK/ads-domain.out" 2>&1; then
  fail 'a foreign seller domain does not authorize Google'
elif grep -q 'is only authorized from google.com' "$WORK/ads-domain.out"; then
  pass 'a foreign seller domain does not authorize Google'
else
  fail 'the seller domain failure names the record'
  cat "$WORK/ads-domain.out" >&2
fi
printf 'google.com, pub-0000000000000000, DIRECT, f08c47fec0942fa0 extra\n' \
  >"$WORK/public/ads.txt"
if "$ROOT/scripts/check-build.sh" "$WORK/public" --mode theme --site "$ROOT/test/fixture" \
    >"$WORK/ads-authority.out" 2>&1; then
  fail 'a malformed ads.txt authority field fails the gate'
elif grep -q "is not Google's TAG ID" "$WORK/ads-authority.out"; then
  pass 'a malformed ads.txt authority field fails the gate'
else
  fail 'the authority failure names the malformed field'
  cat "$WORK/ads-authority.out" >&2
fi
printf 'google.com, pub-0000000000000000, DIRECT, hello\n' \
  >"$WORK/public/ads.txt"
if "$ROOT/scripts/check-build.sh" "$WORK/public" --mode theme --site "$ROOT/test/fixture" \
    >"$WORK/ads-fake-authority.out" 2>&1; then
  fail 'a counterfeit ads.txt authority value fails the gate'
elif grep -q 'is not Google' "$WORK/ads-fake-authority.out"; then
  pass 'a counterfeit ads.txt authority value fails the gate'
else
  fail 'the counterfeit authority failure names the TAG ID'
  cat "$WORK/ads-fake-authority.out" >&2
fi
printf 'google.com, pub-0000000000000000, DIRECT, f08c47fec0942fa0, garbage\n' \
  >"$WORK/public/ads.txt"
if "$ROOT/scripts/check-build.sh" "$WORK/public" --mode theme --site "$ROOT/test/fixture" \
    >"$WORK/ads-stray-field.out" 2>&1; then
  fail 'a five-field ads.txt record fails the gate'
elif grep -q 'anything past that comma is stray' "$WORK/ads-stray-field.out"; then
  pass 'a five-field ads.txt record fails the gate'
else
  fail 'the stray-field failure names the record shape'
  cat "$WORK/ads-stray-field.out" >&2
fi
# Variable declarations from the IAB 1.1 ads.txt section: OWNERDOMAIN and
# MANAGERDOMAIN (which carries commas of its own) are not seller records, so
# a compliant file mixing both must clear the gate untouched.
printf 'OWNERDOMAIN=example.com\nMANAGERDOMAIN=manager.example, US\n%s' \
  "$(cat "$WORK/ads-original.txt")" >"$WORK/public/ads.txt"
if "$ROOT/scripts/check-build.sh" "$WORK/public" --mode theme --site "$ROOT/test/fixture" \
    >"$WORK/ads-variables.out" 2>&1; then
  pass 'variable declarations within legal ads.txt pass the gate'
else
  fail 'variable declarations within legal ads.txt pass the gate'
  cat "$WORK/ads-variables.out" >&2
fi
cp "$WORK/ads-original.txt" "$WORK/public/ads.txt"

# The client regex tightened to the official shape: 16 digits after
# ca-pub-, and AdSense for Platforms' ca-host-pub-… never in data-ad-client.
printf '[ads]\n  client = "ca-host-pub-0000000000000000"\n  consent = "none"\n' \
  >"$ADS_SCRATCH/config/_default/params.toml"
if scratch_hugo; then
  fail 'a ca-host-pub-… client fails the shortcode'
elif grep -q 'belongs in data-ad-host' "$WORK/scratch-build.stderr"; then
  pass 'a ca-host-pub-… client fails the shortcode'
else
  fail 'the host-client failure names data-ad-host'
  cat "$WORK/scratch-build.stderr" >&2
fi
printf '[ads]\n  client = "ca-pub-00000000000000000"\n  consent = "none"\n' \
  >"$ADS_SCRATCH/config/_default/params.toml"
if scratch_hugo; then
  fail 'a 17-digit publisher ID fails the shortcode'
elif grep -q 'does not look like a ca-pub-… publisher ID' \
    "$WORK/scratch-build.stderr"; then
  pass 'a 17-digit publisher ID fails the shortcode'
else
  fail 'the publisher-shape failure names the official format'
  cat "$WORK/scratch-build.stderr" >&2
fi
cp "$WORK/params-original.toml" "$ADS_SCRATCH/config/_default/params.toml"

# Auto-only paths: head ships the loader URL straight from [ads] client, so
# the same shape gate holds with no shortcode anywhere in the site. And the
# auto intent does not survive without the client it needs.
mv "$ADS_SCRATCH/content/ads-page.md" "$WORK/ads-page-stowed.md"
printf '[ads]\n  auto = true\n  consent = "none"\n' \
  >"$ADS_SCRATCH/config/_default/params.toml"
if scratch_hugo; then
  fail 'auto without a client fails the build'
elif grep -q 'needs site.Params.ads.client' "$WORK/scratch-build.stderr"; then
  pass 'auto without a client fails the build'
else
  fail 'the auto-without-client failure names the fix'
  cat "$WORK/scratch-build.stderr" >&2
fi
printf '[ads]\n  client = "ca-pub-00000000000000000"\n  consent = "none"\n  auto = true\n' \
  >"$ADS_SCRATCH/config/_default/params.toml"
if scratch_hugo; then
  fail 'a malformed client fails the auto-only head too'
elif grep -q 'a ca-pub-… publisher ID' "$WORK/scratch-build.stderr"; then
  pass 'a malformed client fails the auto-only head too'
else
  fail 'the auto-only publisher failure names the shape'
  cat "$WORK/scratch-build.stderr" >&2
fi
printf '[ads]\n  client = "ca-host-pub-0000000000000000"\n  consent = "none"\n  auto = true\n' \
  >"$ADS_SCRATCH/config/_default/params.toml"
if scratch_hugo; then
  fail 'a ca-host-pub-… client fails the auto-only head too'
elif grep -q 'belongs in data-ad-host' "$WORK/scratch-build.stderr"; then
  pass 'a ca-host-pub-… client fails the auto-only head too'
else
  fail 'the auto-only host-client failure names data-ad-host'
  cat "$WORK/scratch-build.stderr" >&2
fi
mv "$WORK/ads-page-stowed.md" "$ADS_SCRATCH/content/ads-page.md"
cp "$WORK/params-original.toml" "$ADS_SCRATCH/config/_default/params.toml"

# gated consent with a renamed-away "basic" value gets its own rename hint.
printf '[ads]\n  client = "ca-pub-0000000000000000"\n  consent = "basic"\n' \
  >"$ADS_SCRATCH/config/_default/params.toml"
if scratch_hugo; then
  fail 'the retired "basic" value names its successor'
elif grep -q 'rename it to "gated"' "$WORK/scratch-build.stderr"; then
  pass 'the retired "basic" value names its successor'
else
  fail 'the basic-value failure names the rename'
  cat "$WORK/scratch-build.stderr" >&2
fi
cp "$WORK/params-original.toml" "$ADS_SCRATCH/config/_default/params.toml"

# gated with no consent hook anywhere: every unit would hide forever, so the
# build demands the hook — or an explicit externalConsentController.
mv "$ADS_SCRATCH/layouts/partials/cookie-consent.html" "$WORK/hook-stowed.html"
printf '[ads]\n  client = "ca-pub-0000000000000000"\n  consent = "gated"\n' \
  >"$ADS_SCRATCH/config/_default/params.toml"
if scratch_hugo; then
  fail 'gated with no consent hook fails the build'
elif grep -q 'externalConsentController' "$WORK/scratch-build.stderr"; then
  pass 'gated with no consent hook fails the build'
else
  fail 'the missing-hook failure names the exemption'
  cat "$WORK/scratch-build.stderr" >&2
fi
printf '[ads]\n  client = "ca-pub-0000000000000000"\n  consent = "gated"\n  externalConsentController = true\n' \
  >"$ADS_SCRATCH/config/_default/params.toml"
if scratch_hugo \
   && ! grep -qE 'adsbygoogle\.js\?client=' "$ADS_SCRATCH-public/ads-page/index.html" \
   && grep -qE 'data-ads-consent=.?gated' "$ADS_SCRATCH-public/ads-page/index.html"; then
  pass 'externalConsentController stands in for the missing hook'
else
  fail 'externalConsentController stands in for the missing hook'
  cat "$WORK/scratch-build.stderr" >&2
fi
mv "$WORK/hook-stowed.html" "$ADS_SCRATCH/layouts/partials/cookie-consent.html"
cp "$WORK/params-original.toml" "$ADS_SCRATCH/config/_default/params.toml"

if [ "$FAILURES" -gt 0 ]; then
  printf 'validate-theme: %s failure(s)\n' "$FAILURES" >&2
  exit 1
fi
printf 'validate-theme: all checks passed\n'

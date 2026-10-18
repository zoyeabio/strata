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
# pages exist and the banner points at them.
if grep -q 'href="/cookies/"' "$ROOT/exampleSite/layouts/partials/cookie-consent.html" \
   && grep -q 'href="/privacy-policy/"' "$ROOT/exampleSite/layouts/partials/cookie-consent.html" \
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

if [ "$FAILURES" -gt 0 ]; then
  printf 'validate-theme: %s failure(s)\n' "$FAILURES" >&2
  exit 1
fi
printf 'validate-theme: all checks passed\n'

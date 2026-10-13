#!/usr/bin/env bash
# Validate the theme's own build output.
#
# Usage: ./scripts/validate-theme.sh
#
# Builds test/fixture in production mode twice: without drafts the build
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

if ! hugo --source "$ROOT/test/fixture" --environment production \
    --destination "$WORK/public" 2>"$WORK/build.stderr" >/dev/null; then
  fail 'fixture builds in production mode'
  cat "$WORK/build.stderr" >&2
  exit 1
fi
pass 'fixture builds in production mode'

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
              ("image", "og"), ("build", "pageimageskb"), ("build", "minwidth"))
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
if hugo --source "$ROOT/test/fixture" --environment production --buildDrafts \
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

if [ "$FAILURES" -gt 0 ]; then
  printf 'validate-theme: %s failure(s)\n' "$FAILURES" >&2
  exit 1
fi
printf 'validate-theme: all checks passed\n'

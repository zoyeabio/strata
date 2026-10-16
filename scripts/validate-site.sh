#!/usr/bin/env bash
# Validate a site against the local theme checkout.
#
# Usage: ./scripts/validate-site.sh /path/to/site
#
# Builds the site's minified production artifact with the theme module replaced by this
# checkout through HUGO_MODULE_REPLACEMENTS — the site tree is never written
# to — then delegates output rules to scripts/check-build.sh --mode site.
# See that script for the rule set.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE="${1:?Usage: ./scripts/validate-site.sh /path/to/site}"
MODULE="example.com/strata"
if [ ! -d "$SITE" ]; then
  printf 'ERROR: no such site directory: %s\n' "$SITE" >&2
  exit 2
fi
# Hugo 0.161.0+ runs the TailwindCSS CLI through node. A site that ran `npm
# install` puts it in its own node_modules/.bin, which is not on PATH by
# default — the same reason `npm run` adds it. Fall back to this checkout's
# install for a site that has not wired it yet.
for bin in "$SITE/node_modules/.bin" "$ROOT/node_modules/.bin"; do
  if [ -d "$bin" ]; then
    PATH="$bin:$PATH"
    export PATH
  fi
done
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Fail fast if the site imports a different theme. The build still succeeds —
# against that other theme — and every rule below would judge output this
# checkout never produced, reading as a wall of failures that say nothing about
# it. Seen once: a not-yet-migrated site reported 8 failures that were all the
# previous theme's output, including JSON-LD this checkout does not emit.
# Hugo's default scaffold keeps config at the repository root instead of in
# config/, so both places are searched; a glob with no match is skipped by
# grep rather than aborting the check.
found="$(grep -rhoE '"[^"]*\.[a-z]{2,}/[^"]*"' \
  "$SITE/config" "$SITE"/hugo*.toml "$SITE"/config*.toml 2>/dev/null | sort -u || true)"
if ! printf '%s\n' "$found" | grep -qF "$MODULE"; then
  have="$(printf '%s\n' "$found" | grep -vF "$MODULE" | paste -sd, - || true)"
  printf 'ERROR: %s does not import %s\n' "$SITE" "$MODULE" >&2
  printf '  searched: config/, hugo*.toml, config*.toml\n' >&2
  printf '  found: %s\n' "${have:-no module imports}" >&2
  printf 'these rules judge strata output; migrate the site first\n' >&2
  exit 3
fi

if ! HUGO_MODULE_REPLACEMENTS="$MODULE -> $ROOT" \
    HUGO_CACHEDIR="$WORK/cache" \
    hugo --source "$SITE" --environment production --minify \
      --destination "$WORK/public" 2>"$WORK/build.stderr" >/dev/null; then
  printf 'FAIL site builds in production mode against the local theme\n' >&2
  cat "$WORK/build.stderr" >&2
  exit 1
fi
printf 'ok   site builds a minified production artifact against the local theme\n'
if [ -s "$WORK/build.stderr" ]; then
  printf 'warn build warnings:\n'
  cat "$WORK/build.stderr"
fi

FAILURES=0
pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }

# Taxonomies are site-owned. A content site can declare tags/series; a compact
# brochure site can explicitly disable them with an empty [taxonomies] table.
# Requiring the table to exist avoids Hugo's implicit tags/categories defaults.
if taxonomy_mode=$(python3 - "$ROOT" "$SITE" <<'PY'
import pathlib
import sys

theme_root = pathlib.Path(sys.argv[1])
site_root = pathlib.Path(sys.argv[2])
sys.path.insert(0, str(theme_root / "scripts" / "lib"))
from build_config import _load_config, _merge, _toml_files

seen = False
taxonomies = {}
disabled = set()
for path in _toml_files(site_root):
    data = _load_config(path)
    if "taxonomies" in data:
        seen = True
        taxonomies = _merge(taxonomies, data["taxonomies"] or {})
    if "disableKinds" in data or "disablekinds" in data:
        values = data.get("disableKinds", data.get("disablekinds")) or []
        disabled |= {str(value).lower() for value in values}

if {"taxonomy", "term"} <= disabled:
    print("site explicitly disables taxonomy and term pages")
elif not seen:
    print("site must declare [taxonomies] or an empty [taxonomies] table; "
          "otherwise Hugo enables tags and categories implicitly")
    sys.exit(1)
elif not taxonomies:
    print("site explicitly disables taxonomies with an empty [taxonomies] table")
else:
    expected = {"tag": "tags", "series": "series"}
    wrong = [f"{key}={taxonomies[key]!r} (want {plural!r})"
             for key, plural in expected.items()
             if key in taxonomies and str(taxonomies[key]) != plural]
    if wrong:
        print("unsupported Strata taxonomy mapping: " + ", ".join(wrong))
        sys.exit(1)
    active = [plural for key, plural in expected.items() if key in taxonomies]
    print("site enables " + (" and ".join(active) if active else "custom taxonomies"))
PY
); then
  pass "$taxonomy_mode"
else
  fail "$taxonomy_mode"
fi

# Front matter is upstream of everything the build reports. An unknown key, an
# empty description and a lastmod before date all build cleanly and only show
# up in the JSON-LD, so the source is linted rather than the output.
if "$ROOT/scripts/validate-content.sh" "$SITE"
then
  pass 'the site front matter is complete and free of unknown keys'
else
  fail 'the site front matter is complete and free of unknown keys'
fi

# A site's own data/sharing.json merges over the theme's, and Hugo's printf
# does not error on a share URL with the wrong verb count: it appends
# %!N(EXTRA ...) into the link and the button silently stops working. The
# theme's own defaults are checked in validate-theme.sh; this is where a site
# override can land, so the merged pair is checked here. The merge for this
# shape is a flat per-name replace, which is how Hugo merges data files.
if sharing_out=$(python3 - "$ROOT" "$SITE" <<'PY'
import json
import pathlib
import re
import sys

theme_root = pathlib.Path(sys.argv[1])
site_root = pathlib.Path(sys.argv[2])
data = {}
for p in (theme_root / "data/sharing.json", site_root / "data/sharing.json"):
    if p.exists():
        data.update(json.loads(p.read_text()))

bad = []
for name, svc in sorted(data.items()):
    if not isinstance(svc, dict) or "url" not in svc:
        bad.append("%s: no url" % name)
        continue
    verbs = re.findall(r'%\[\d+\][a-z]|%[a-z]', svc["url"])
    if len(verbs) != 2:
        bad.append("%s: %d verb(s) %s, want 2 — %r" % (name, len(verbs), verbs, svc["url"]))
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

if "$ROOT/scripts/check-build.sh" "$WORK/public" --mode site --site "$SITE"; then
  pass 'check-build site mode'
else
  fail 'check-build site mode'
fi

if [ "$FAILURES" -gt 0 ]; then
  printf 'validate-site: %s failure(s)\n' "$FAILURES" >&2
  exit 1
fi
printf 'validate-site: all checks passed\n'

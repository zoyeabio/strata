#!/usr/bin/env bash
# Validate a site against the local theme checkout.
#
# Usage: ./scripts/validate-site.sh /path/to/site
#
# Builds the site in production mode with the theme module replaced by this
# checkout through HUGO_MODULE_REPLACEMENTS — the site tree is never written
# to — then delegates output rules to scripts/check-build.sh --mode site.
# See that script for the rule set.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE="${1:?Usage: ./scripts/validate-site.sh /path/to/site}"
if [ ! -d "$SITE" ]; then
  printf 'ERROR: no such site directory: %s\n' "$SITE" >&2
  exit 2
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Fail fast if the site imports a different theme. The build still succeeds —
# against that other theme — and every rule below would judge output this
# checkout never produced, reading as a wall of failures that say nothing about
# it. Seen once: a not-yet-migrated site reported 8 failures that were all the
# previous theme's output, including JSON-LD this checkout does not emit.
if ! grep -rq 'github.com/zoyeabio/strata' "$SITE/config" 2>/dev/null; then
  have="$(grep -rhoE 'github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' "$SITE/config" \
    2>/dev/null | grep -v 'zoyeabio/strata' | sort -u | paste -sd, - || true)"
  printf 'ERROR: %s does not import github.com/zoyeabio/strata (found: %s)\n' \
    "$SITE" "${have:-no module imports}" >&2
  printf 'these rules judge strata output; migrate the site first\n' >&2
  exit 2
fi

if ! HUGO_MODULE_REPLACEMENTS="github.com/zoyeabio/strata -> $ROOT" \
    HUGO_CACHEDIR="$WORK/cache" \
    hugo --source "$SITE" --environment production \
      --destination "$WORK/public" 2>"$WORK/build.stderr" >/dev/null; then
  printf 'FAIL site builds in production mode against the local theme\n' >&2
  cat "$WORK/build.stderr" >&2
  exit 1
fi
printf 'ok   site builds in production mode against the local theme\n'
if [ -s "$WORK/build.stderr" ]; then
  printf 'warn build warnings:\n'
  cat "$WORK/build.stderr"
fi

FAILURES=0
pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }

# The theme's taxonomy contract: the header tag links and the series nav
# read the "tags" and "series" taxonomies. Hugo does not inherit a theme's
# [taxonomies], so the host site must declare them; a missing one does not
# fail the build, it just silently drops tag links or series navigation.
cfg="$(HUGO_MODULE_REPLACEMENTS="github.com/zoyeabio/strata -> $ROOT" \
  HUGO_CACHEDIR="$WORK/cache" hugo config --source "$SITE" 2>/dev/null \
  | tr -d "'" | awk '/^\[taxonomies\]/{f=1;next} /^\[/{f=0} f' | sed 's/^[[:space:]]*//' \
  | sed -n 's/^[^=]*=[[:space:]]*//p')"
missing_tax=""
for plural in tags series; do
  printf '%s\n' "$cfg" | grep -qx "$plural" || missing_tax="$missing_tax $plural"
done
if [ -z "$missing_tax" ]; then
  pass 'site declares the tags and series taxonomies'
else
  fail "site is missing [taxonomies] values:$missing_tax — tag links or series nav will vanish silently"
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

if "$ROOT/scripts/check-build.sh" "$WORK/public" --mode site; then
  pass 'check-build site mode'
else
  fail 'check-build site mode'
fi

if [ "$FAILURES" -gt 0 ]; then
  printf 'validate-site: %s failure(s)\n' "$FAILURES" >&2
  exit 1
fi
printf 'validate-site: all checks passed\n'

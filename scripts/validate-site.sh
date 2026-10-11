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

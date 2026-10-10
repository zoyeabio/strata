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

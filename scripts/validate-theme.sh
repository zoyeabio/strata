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

if "$ROOT/scripts/check-build.sh" "$WORK/public" --mode theme; then
  pass 'check-build theme mode'
else
  fail 'check-build theme mode'
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

if [ "$FAILURES" -gt 0 ]; then
  printf 'validate-theme: %s failure(s)\n' "$FAILURES" >&2
  exit 1
fi
printf 'validate-theme: all checks passed\n'

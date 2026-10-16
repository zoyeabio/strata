#!/usr/bin/env bash
# Check that exampleSite still demonstrates the theme's public surface.
#
# Usage: ./scripts/validate-example.sh [theme_root]
#
# test/fixture is a gate harness that asserts mechanically. exampleSite is the
# other kind of test, the one a reader can see: every shortcode with a live
# example, every site hook with a working implementation to copy from. Nothing
# enforces that coverage today. A new shortcode can ship with no example, a new
# hook with no implementation, and a hook the theme stops probing leaves a dead
# file behind. Every list here is derived from the theme's own tree, so there is
# no hand-written inventory to keep in step.
#
# Shortcode and hook coverage fail. Page-level front matter key coverage is
# advisory: some overrides have no sensible page to demonstrate them on, and
# forcing one would mean writing content about the feature rather than the
# product.
#
# Exit status: 0 clean, 1 coverage broken, 2 environment or usage error.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME="${1:-$ROOT}"

if [ ! -d "$THEME/layouts" ]; then
  printf 'ERROR: no layouts/ under %s\n' "$THEME" >&2
  exit 2
fi
if [ ! -d "$THEME/exampleSite" ]; then
  printf 'ERROR: no exampleSite under %s\n' "$THEME" >&2
  exit 2
fi

FAILURES=0
pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }

if python3 - "$THEME" <<'PY'
import pathlib
import re
import sys

theme = pathlib.Path(sys.argv[1])
site = theme / "exampleSite"
problems = []


def text(path):
    return path.read_text(encoding="utf-8", errors="ignore")


# A shortcode that cannot be demonstrated without credentials a public example
# site cannot hold. Adding an entry here needs a reason, not just silence.
NO_DEMO = {
    "ads": "needs an [ads] client publisher ID and a matching static/ads.txt",
}

pages = {
    str(p.relative_to(site / "content")): text(p)
    for p in sorted((site / "content").rglob("*.md"))
}


def uses_shortcode(name, body):
    """{{< name >}} and [[ name(...]]] both count."""
    esc = re.escape(name)
    return bool(re.search(r"\{\{[ <]+" + esc + r"[ >]", body)
                or re.search(r"\[\[" + esc + r"[ \t]*\(", body))


for file in sorted((theme / "layouts" / "shortcodes").rglob("*.html")):
    name = file.relative_to(theme / "layouts" / "shortcodes")
    name = name.with_suffix("").as_posix()
    hits = [path for path, body in pages.items() if uses_shortcode(name, body)]
    if not hits:
        if name in NO_DEMO:
            print("warn shortcode %s has no live example: %s" % (name, NO_DEMO[name]))
        else:
            problems.append("shortcode %s has no live example" % name)
else:
    print("ok   %d shortcodes" % sum(1 for _ in
          (theme / "layouts" / "shortcodes").rglob("*.html")))

# --- site hooks -------------------------------------------------------------
# The theme probes an optional partial with templates.Exists. The path may carry
# a partials/ prefix, which the implementation file does not.
probed = set()
for file in (theme / "layouts").rglob("*.html"):
    for match in re.finditer(r'templates\.Exists\s+"([^"]+)"', text(file)):
        probed.add(match.group(1).replace("partials/", ""))

hook_dir = site / "layouts" / "partials"
implemented = {p.name for p in hook_dir.glob("*.html")} if hook_dir.is_dir() else set()

for hook in sorted(probed):
    if hook not in implemented:
        problems.append(
            "hook %s has no implementation in exampleSite/layouts/partials/" % hook)
for hook in sorted(implemented - probed):
    problems.append(
        "exampleSite implements %s but the theme no longer probes it" % hook)
print("ok   %d site hooks" % len(probed))

# --- page-level front matter keys, advisory ---------------------------------
# ATTR_KEY and QUOTED_KEY must stay identical to scripts/validate-content.sh,
# which owns the same extraction and the allowlist built from it.
ATTR_KEY = re.compile(r"(?<!site\.)(?<!\.Site)\bParams\.(\w+)")
QUOTED_KEY = re.compile(r"(?<!site\.)(?<!\.Site)\bParams\s+[\"'](\w+)[\"']")
# Hugo's reserved front matter fields. Stable upstream, not theme-specific.
HUGO_FIELDS = {
    "title", "description", "date", "lastmod", "weight", "draft", "layout",
    "kind", "slug", "linktitle", "section", "params", "menu", "menus",
    "markup", "cascade", "workflow", "keywords", "author", "summary",
    "expires", "resources", "related", "geocoordinates", "output", "head",
    "content", "math", "highlight", "rsscenter", "_build",
}

read_keys = set()
for file in (theme / "layouts").rglob("*"):
    if file.is_file():
        body = text(file)
        read_keys |= set(ATTR_KEY.findall(body)) | set(QUOTED_KEY.findall(body))
read_keys = {k.lower() for k in read_keys} - HUGO_FIELDS

used_keys = set()
for body in pages.values():
    block = re.match(r"^---\n(.*?)\n---", body, re.S)
    if not block:
        continue
    for line in block.group(1).splitlines():
        line = line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        if line.startswith("-"):
            continue
        used_keys.add(line.split(":")[0].strip().lower())

undemonstrated = sorted(read_keys - used_keys)
if undemonstrated:
    print("warn %d page-level keys are read but not demonstrated: %s"
          % (len(undemonstrated), ", ".join(undemonstrated)))
else:
    print("ok   every page-level key is demonstrated")

if problems:
    for problem in problems:
        print("FAIL %s" % problem, file=sys.stderr)
    print("validate-example: %d gap(s)" % len(problems), file=sys.stderr)
    sys.exit(1)
print("validate-example: clean")
PY
then
  pass "exampleSite demonstrates the theme's public surface"
else
  fail 'exampleSite demonstrates the theme public surface'
fi

if [ "$FAILURES" -gt 0 ]; then
  exit 1
fi
exit 0

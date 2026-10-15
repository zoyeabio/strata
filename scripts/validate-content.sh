#!/usr/bin/env bash
# Lint a site's front matter for the failures a build cannot report.
#
# Usage: ./scripts/validate-content.sh /path/to/site
#
# check-build.sh judges rendered output, which is already downstream of a
# silent skip. A page carrying an unknown front matter key still builds, a
# lastmod earlier than date still publishes as dateModified before
# datePublished, and a featureimage without an alt still ships a generic one.
# Those land in JSON-LD and in search results and nothing in the build
# complains, so this reads the source instead of the output.
#
# The allowed key list is derived from the theme's own templates rather than
# written down by hand: a hand-written list is a second source of truth and it
# rots. Allowed are the keys layouts/ reads, plus Hugo's reserved front matter
# fields and the taxonomies the site declares.
#
# Exit status: 0 clean, 1 problems found, 2 environment or usage error.
# Only FAIL lines set the exit status; warn lines are advisory.
#
# Run this on exampleSite (validate-theme.sh) and on a consuming site
# (validate-site.sh). test/fixture is a gate harness with deliberately minimal
# front matter, so it does not pass this lint and is not judged by any gate.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE="${1:?Usage: ./scripts/validate-content.sh /path/to/site}"

if [ ! -d "$SITE" ]; then
  printf 'ERROR: no such site directory: %s\n' "$SITE" >&2
  exit 2
fi

FAILURES=0
pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }

if python3 - "$ROOT" "$SITE" <<'PY'
import pathlib
import re
import sys
from datetime import date, datetime

try:
    import yaml
except ImportError:
    sys.stderr.write("pyyaml is required: python3 -m pip install pyyaml\n")
    sys.exit(2)

theme_root = pathlib.Path(sys.argv[1])
site_root = pathlib.Path(sys.argv[2])
sys.path.insert(0, str(theme_root / "scripts" / "lib"))
from build_config import _get, _load, _load_config, _merge, _toml_files

# Front matter keys Hugo turns into Page fields. They are not params, so they
# are not checked against the theme's template-derived list.
HUGO_FIELDS = {
    "title", "description", "date", "lastmod", "weight", "draft", "layout",
    "kind", "slug", "linktitle", "section", "params", "menu", "menus",
    "markup", "cascade", "workflow", "keywords", "author", "summary",
    "expires", "resources", "related", "geocoordinates", "output", "head",
    "content", "math", "highlight", "rsscenter", "_build",
}
# A page's Params, not the site's: site.Params.readingMeasure must not leak a
# site config key into the allowed front matter list.
ATTR_KEY = re.compile(r"(?<!site\.)(?<!\.Site)\bParams\.(\w+)")
QUOTED_KEY = re.compile(r"(?<!site\.)(?<!\.Site)\bParams\s+[\"'](\w+)[\"']")
SKIP_DIRS = {"public", "node_modules", "resources", "_build", ".git", "i18n"}
DESCRIPTION_SOFT_LIMIT = 200

problems = []


def bad(rule, detail):
    problems.append((rule, detail))
    print("FAIL %s" % rule)
    for line in str(detail).splitlines():
        print("  %s" % line)


def theme_param_keys():
    """Every front matter key a template reads, lowercased."""
    keys = set()
    for page in (theme_root / "layouts").rglob("*"):
        if not page.is_file():
            continue
        text = page.read_text(encoding="utf-8")
        keys |= set(ATTR_KEY.findall(text))
        keys |= set(QUOTED_KEY.findall(text))
    return {key.lower() for key in keys}


def declared_taxonomies():
    """The taxonomy keys and plural names the site declares."""
    keys, plurals = set(), set()
    for path in _toml_files(site_root):
        tax = _load(path).get("taxonomies") or {}
        for key, plural in tax.items():
            keys.add(key.lower())
            plurals.add(str(plural).lower())
    return keys, plurals


def site_author():
    """site.Params.author.name, merged the way Hugo merges the config files.
    The theme ships an empty name, so a site that never sets one gets None."""
    cfg = {}
    for path in _toml_files(site_root):
        cfg = _merge(cfg, _load_config(path))
    return _get(cfg.get("params") or {}, ("author", "name"))


def rel_of(path):
    return str(path.relative_to(site_root))


def pages():
    """Content files Hugo renders as articles. Hugo-prefixed names are skipped:
    section indexes and term archives render through list templates, not as
    articles, so the article rules do not apply to them."""
    for path in sorted((site_root / "content").rglob("*.md")):
        if not path.is_file():
            continue
        parts = path.relative_to(site_root).parts
        if any(part in SKIP_DIRS for part in parts):
            continue
        if any(part.startswith(".") or part.startswith("_") for part in parts):
            continue
        yield path


def param_of(params, key):
    """Values under the params block. Hugo puts them in .Params just like the
    top level does, so both spellings mean the same thing to the templates."""
    if not isinstance(params, dict):
        return None
    return params.get(key)


def param_keys_of(params):
    """The key names written under params, or {} when there are none."""
    return dict(params) if isinstance(params, dict) else {}


def as_date(value):
    """Hugo accepts a date, a datetime or a string; YAML unparses the first two."""
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if isinstance(value, str):
        for fmt in ("%Y-%m-%d", "%Y/%m/%d", "%Y-%m-%dT%H:%M:%S"):
            try:
                return datetime.strptime(value.strip(), fmt).date()
            except ValueError:
                pass
    return None


def front_matter(path):
    """The page's front matter, or {} when the file has none."""
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return {}
    parts = text.split("---", 2)
    if len(parts) < 3:
        return {}
    try:
        data = yaml.safe_load(parts[1])
    except yaml.YAMLError as exc:
        bad("front matter parses as YAML", "%s: %s" % (rel_of(path), exc))
        return {}
    if not isinstance(data, dict):
        bad("front matter is a mapping",
            "%s: got %s" % (rel_of(path), type(data).__name__))
        return {}
    return data


whitelist = theme_param_keys()
tax_keys, tax_plurals = declared_taxonomies()
allowed = whitelist | HUGO_FIELDS | tax_keys | tax_plurals
site_author_name = site_author()

seen = 0
dated = 0
drafts = 0
for path in pages():
    seen += 1
    fm = front_matter(path)
    if not fm:
        continue
    if fm.get("draft"):
        # Drafts never publish, so their metadata never reaches search engines.
        # They are exercised by the --buildDrafts build instead.
        drafts += 1
        continue
    where = rel_of(path)
    params = fm.get("params")

    param_keys = {key for key in fm if key.lower() not in HUGO_FIELDS}
    param_keys |= set(param_keys_of(params))
    stray = sorted(key for key in param_keys if key.lower() not in allowed)
    if stray:
        bad("unknown front matter key",
            "%s: %s — the theme reads nothing named this, so it is silently ignored"
            % (where, ", ".join(stray)))

    if not fm.get("title"):
        bad("title is required", "%s: every rendered page needs one" % where)

    published = as_date(fm.get("date"))
    if published:
        dated += 1
        if not (fm.get("description") or param_of(params, "summary")):
            bad("a dated page needs a description",
                "%s: meta description, og:description and Article.description all "
                "fall back to the site default or the bare title" % where)
        if not (fm.get("keywords") or fm.get("tags") or param_of(params, "keywords")):
            bad("a dated page needs keywords or tags",
                "%s: meta keywords and Article.keywords are empty without them" % where)
        modified = as_date(fm.get("lastmod"))
        if modified and modified < published:
            bad("lastmod is not before date",
                "%s: dateModified %s precedes datePublished %s, which search "
                "engines reject" % (where, modified, published))
        description = fm.get("description")
        if isinstance(description, str) and len(description) > DESCRIPTION_SOFT_LIMIT:
            print("warn %s: description is %d chars, search engines truncate near 155"
                  % (where, len(description)))
    elif fm.get("lastmod"):
        bad("lastmod without date",
            "%s: with no date the page never renders as an article and lastmod "
            "goes nowhere" % where)

    if fm.get("featureimage") or param_of(params, "featureimage"):
        if not (fm.get("featureimagealt") or param_of(params, "featureimagealt")):
            bad("featureimage needs featureimagealt",
                "%s: the hero, the card and og:image:alt all fall back to a "
                "generic caption" % where)

    author = fm.get("author")
    if isinstance(author, (list, dict)):
        bad("author is a single string",
            "%s: the theme prints the value directly, so a list renders as a "
            "bracketed run" % where)

    authorurl = fm.get("authorurl") or param_of(params, "authorurl")
    if authorurl and not (author or site_author_name):
        bad("authorurl needs author",
            "%s: neither the page nor site.Params.author.name is set, so no "
            "byline renders and the url goes nowhere" % where)

print("ok   scanned %d content pages, %d dated, %d drafts skipped"
      % (seen, dated, drafts))

if problems:
    print("validate-content: %d problem(s)" % len(problems), file=sys.stderr)
    sys.exit(1)
print("validate-content: clean")
PY
then
  pass "front matter is complete and free of unknown keys"
else
  fail 'front matter is complete and free of unknown keys'
fi

if [ "$FAILURES" -gt 0 ]; then
  exit 1
fi
exit 0

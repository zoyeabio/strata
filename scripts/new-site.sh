#!/usr/bin/env bash
# Scaffold a new site against the local Strata theme checkout.
#
# Usage:
#   ./scripts/new-site.sh \
#     --name "Example" --slug example --domain example.com \
#     --out ../example --accent "#295f8f" \
#     --sections "journal,resources"
#
# Generates the minimal site layer the theme consumes: config with the
# taxonomy contract, archetype, content skeleton, image directories, static
# files, go.mod, .gitignore and a short site README. The scaffold contains
# no dead parameter keys — everything in the generated config is read by the
# theme.
#
# Every site command below is read from this theme checkout:
#   validate-site.sh /path/to/site   # production build + output rules
#   hugo --minify                    # with the module replaced locally
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  sed -n '2,14p' "$0"
}

NAME=""
SLUG=""
DOMAIN=""
OUT=""
ACCENT="#295f8f"
SECTIONS=""
MODULE_VERSION="v0.3.0"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --slug) SLUG="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --accent) ACCENT="$2"; shift 2 ;;
    --sections) SECTIONS="$2"; shift 2 ;;
    --module-version) MODULE_VERSION="$2"; shift 2 ;;
    *) printf 'ERROR: unknown option %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$NAME" ]; then printf 'ERROR: --name is required\n' >&2; usage >&2; exit 2; fi
if [ -z "$DOMAIN" ]; then printf 'ERROR: --domain is required\n' >&2; usage >&2; exit 2; fi
if [ -z "$OUT" ]; then printf 'ERROR: --out is required\n' >&2; usage >&2; exit 2; fi

if [ -z "$SLUG" ]; then
  SLUG=$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
fi

if [ -e "$OUT" ]; then
  printf 'ERROR: output already exists: %s\n' "$OUT" >&2
  exit 2
fi

if ! printf '%s' "$ACCENT" | grep -qE '^#[0-9a-fA-F]{6}$'; then
  printf 'ERROR: --accent must be a hex colour like #295f8f\n' "$ACCENT" >&2
  exit 2
fi

mkdir -p "$OUT"
trap 'printf "removing partial scaffold %s\n" "$OUT" >&2; rm -rf "$OUT"' ERR

mkdir -p \
  "$OUT/config/_default" \
  "$OUT/archetypes" \
  "$OUT/content" \
  "$OUT/assets/css" \
  "$OUT/assets/images" \
  "$OUT/static" \
  "$OUT/.github/workflows"

# config/_default/hugo.toml — nothing beyond the theme contract and the
# site's own authored settings
cat > "$OUT/config/_default/hugo.toml" <<EOF
baseURL = "https://${DOMAIN}/"
defaultContentLanguage = "en"
title = "${NAME}"

enableRobotsTXT = true
summaryLength = 30
enableEmoji = false

[[cascade]]
  [cascade.build]
    publishResources = false

[module]
  proxy = "direct"

  [[module.imports]]
    path = "github.com/zoyeabio/strata"

[module.hugoVersion]
  extended = true
  min = "0.167.0"

[pagination]
  pagerSize = 12

[taxonomies]
  tag = "tags"
  series = "series"

[sitemap]
  changefreq = 'weekly'
  filename = 'sitemap.xml'
  priority = 0.5

[outputs]
  home = ["HTML", "RSS"]

# Hugo 0.161.0+ runs the TailwindCSS CLI through node, so the tailwindcss
# script and its interpreter must both be allowed, and the tailwindcss addon
# needs its own node policy
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

# Hugo docs css.TailwindCSS recipe: stats + watch wiring so server rebuilds
# stay fresh (the pipeline scans @source files, not hugo_stats.json)
[build.buildStats]
  enable = true

[[build.cachebusters]]
  source = 'assets/notwatching/hugo_stats\.json'
  target = 'css'

[[module.mounts]]
  source = 'assets'
  target = 'assets'

[[module.mounts]]
  disableWatch = true
  source = 'hugo_stats.json'
  target = 'assets/notwatching/hugo_stats.json'
EOF

# config/_default/languages.en.toml
cat > "$OUT/config/_default/languages.en.toml" <<EOF
locale = "en"
label = "English"
weight = 1
title = "${NAME}"

[params]
  displayName = "English"
  isoCode = "en"
  rtl = false
  dateFormat = "2006-01-02"
  description = "${NAME} — independent information site."
  copyright = "Copyright { year } ${NAME}"
EOF

# config/_default/menus.en.toml — sections joined into the main menu first
{
  : > "$OUT/config/_default/menus.en.toml"
  if [ -n "$SECTIONS" ]; then
    weight=10
    IFS=',' read -ra secs <<< "$SECTIONS"
    for sec in "${secs[@]}"; do
      sec=$(printf '%s' "$sec" | xargs)
      if [ -n "$sec" ]; then
        title=$(printf '%s' "$sec" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
        cat >> "$OUT/config/_default/menus.en.toml" <<EOF

[[main]]
  name = "$title"
  pageRef = "${sec}"
  weight = ${weight}
EOF
        weight=$((weight + 10))
      fi
    done
  fi
  cat >> "$OUT/config/_default/menus.en.toml" <<EOF

[[main]]
  name = "About"
  pageRef = "about"
  weight = 900

[[main]]
  name = "Contact"
  pageRef = "contact"
  weight = 910

[[footer]]
  name = "Privacy"
  pageRef = "privacy-policy"
  weight = 10

[[footer]]
  name = "Cookies"
  pageRef = "cookies"
  weight = 15

[[footer]]
  name = "Terms"
  pageRef = "terms"
  weight = 20
EOF
}

# config/_default/params.toml — only keys emitted by the theme
cat > "$OUT/config/_default/params.toml" <<EOF
colorScheme = "default"
defaultAppearance = "light"
autoSwitchAppearance = true

[list]
  cardView = true
  showSummary = true
EOF

# custom accent via the site layer; the theme's scheme stays intact
if [ "$ACCENT" != "#295f8f" ]; then
  cat > "$OUT/assets/css/site.css" <<EOF
:root {
  --site-accent: $ACCENT;
}
EOF
  cat >> "$OUT/config/_default/params.toml" <<EOF
customCSS = ["css/site.css"]
EOF
fi

# archetypes/default/index.md — directory archetype, so `hugo new
# section/slug` creates content/section/slug/index.md. Images stay outside the
# content tree in assets/images/section/slug/.
mkdir -p "$OUT/archetypes/default"
cat > "$OUT/archetypes/default/index.md" <<'EOF'
---
title: "{{ replace .File.ContentBaseName "-" " " | title }}"
description: ""
summary: ""
keywords: []
author: ""
date: {{ .Date }}
lastmod: {{ .Date }}
draft: true
tags: []
series: []
featureimage: ""
featureimagealt: ""
showHero: true
showSummary: true
weight: 0
---
EOF

# content skeleton
cat > "$OUT/content/_index.md" <<EOF
---
title: "${NAME}"
description: "${NAME} — independent information site."
---
Welcome to ${NAME}.
EOF

for dir in about contact; do
  mkdir -p "$OUT/content/$dir"
  title=$(printf '%s' "$dir" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
  cat > "$OUT/content/$dir/_index.md" <<EOF
---
title: "$title"
---
EOF
done

# Legal pages ship as stubs with TODOs in comments and a visible build
# marker, NOT published facts: a privacy policy naming the wrong entity is a
# liability, and the full shape of each one is in the example site's content
# tree. front matter draft: true keeps the stub out of production output, so
# enabling [ads] while the notices are still stubs fails check-build R17
# with "/cookies/ missing" instead of a gate the stub prose sneaks past.
mkdir -p "$OUT/content/cookies" "$OUT/content/privacy-policy" "$OUT/content/terms"

cat > "$OUT/content/cookies/_index.md" <<'EOF'
---
title: "Cookies"
draft: true
---

<!-- TODO: list the cookies and similar technologies this site sets, with
     purpose, provider and lifetime. Delete rows you do not use. -->

Fill this in before publishing. The consent banner links here, and the
example site's Cookies page is the shape to adapt.
EOF

cat > "$OUT/content/privacy-policy/_index.md" <<'EOF'
---
title: "Privacy Policy"
draft: true
---

<!-- TODO: who you are, what you collect, for how long you keep it, who
     you share it with, and what rights a reader has. Consent law needs a
     one-line answer on whether it applies here and on what basis. -->

Fill this in before publishing. The example site's Privacy Policy page is
the shape to adapt.
EOF

cat > "$OUT/content/terms/_index.md" <<'EOF'
---
title: "Terms of Use"
draft: true
---

<!-- TODO: how the site may be used, what copyright you keep, how far your
     liability extends, and the governing law. Use the same contact address
     the privacy policy gives. -->

Fill this in before publishing. The example site's Terms of Use page is
the shape to adapt.
EOF

if [ -n "$SECTIONS" ]; then
  IFS=',' read -ra secs <<< "$SECTIONS"
  for sec in "${secs[@]}"; do
    sec=$(printf '%s' "$sec" | xargs)
    if [ -z "$sec" ]; then
      continue
    fi
    mkdir -p "$OUT/content/$sec"
    title=$(printf '%s' "$sec" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
    cat > "$OUT/content/$sec/_index.md" <<EOF
---
title: "$title"
---
EOF
    mkdir -p "$OUT/assets/images/$sec"
    cat > "$OUT/assets/images/$sec/README.md" <<EOF
Image directory for the $sec section. Put section images here and reference
them from front matter as \`$sec/file.webp\` (or with the full
\`/images/$sec/file.webp\` path).
EOF
  done
fi

# no static/robots.txt: that would shadow the theme's templated fallback,
# which keeps a local `hugo server` out of the index while a production build
# opens the crawl and declares the sitemap
# ads.txt starts as comments only: set [ads] client in config and replace
# the stub line when the publisher ID is known
cat > "$OUT/static/ads.txt" <<'EOF'
# AdSense authorized sellers. Uncomment and set your publisher ID:
# google.com, pub-0000000000000000, DIRECT, f08c47fec0942fa0
EOF

cat > "$OUT/static/site.webmanifest" <<EOF
{
  "name": "${NAME}",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#183229",
  "icons": [
    {
      "src": "/android-chrome-192x192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/android-chrome-512x512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
EOF

# llms.txt is a real discovery file, not a placeholder
{
  printf '# %s\n' "$NAME"
  printf '> https://%s/\n' "$DOMAIN"
  printf -- '- https://%s/\n' "$DOMAIN"
  if [ -n "$SECTIONS" ]; then
    IFS=',' read -ra secs <<< "$SECTIONS"
    for sec in "${secs[@]}"; do
      sec=$(printf '%s' "$sec" | xargs)
      [ -z "$sec" ] || printf -- '- https://%s/%s/\n' "$DOMAIN" "$sec"
    done
  fi
  printf -- '- https://%s/about/\n' "$DOMAIN"
  printf -- '- https://%s/contact/\n' "$DOMAIN"
} > "$OUT/static/llms.txt"

# The require pins the published theme version; the replace points the site
# at this checkout so a scaffold builds against local theme edits. Drop the
# replace to build against the tag instead. The site's own module path stays
# a placeholder: its host is the reader's to choose, not the theme's.
cat > "$OUT/go.mod" <<EOF
module example.com/${SLUG}

go 1.22

require github.com/zoyeabio/strata ${MODULE_VERSION}

replace github.com/zoyeabio/strata => $ROOT
EOF

# package.json — Hugo 0.161.0+ runs the TailwindCSS CLI through node, so the
# build needs an npm install. `npm run build` / `npm run dev` put
# node_modules/.bin on PATH, which is how Hugo finds the tailwindcss script.
# `engines` earns its place: Hugo passes node `--permission`, node 20 rejects
# it, and the build then fails without saying why.
cat > "$OUT/package.json" <<EOF
{
  "name": "$SLUG",
  "private": true,
  "scripts": {
    "dev": "hugo server -D",
    "build": "hugo --minify"
  },
  "dependencies": {
    "@tailwindcss/cli": "4.3.3",
    "@tailwindcss/forms": "0.5.11",
    "@tailwindcss/typography": "0.5.20",
    "tailwindcss": "4.3.3"
  },
  "overrides": {
    "postcss-selector-parser": "6.1.5"
  },
  "engines": {
    "node": ">=22"
  }
}
EOF

# Keep CI reproducible. The generated dependency set deliberately matches the
# theme's own package.json, so its reviewed lockfile is also the scaffold's
# lockfile. npm does not require a private package's name/version metadata to
# match in order to run `npm ci`; it validates the dependency graph below.
cp "$ROOT/package-lock.json" "$OUT/package-lock.json"

# .gitignore
cat > "$OUT/.gitignore" <<'EOF'
resources/
public/
node_modules/
.DS_Store
EOF

# CI runs the same gate the README asks a developer to run by hand, so the
# output rules bind on every push instead of on whoever remembers. Strata is
# a sibling checkout: validate-site.sh takes this repository as its argument
# and builds it against that checkout, which also overrides the local
# `replace` path in go.mod.
cat <<'EOF' | sed "s/__MODULE_VERSION__/${MODULE_VERSION}/g" > "$OUT/.github/workflows/validate.yml"
name: Validate

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  validate:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4

      # `ref` is the tag go.mod requires: the local replace makes
      # development build against your checkout, CI builds the release. Bump
      # both when you upgrade the theme.
      - uses: actions/checkout@v4
        with:
          repository: zoyeabio/strata
          ref: __MODULE_VERSION__
          path: ../strata

      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: npm

      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install Hugo Extended
        env:
          HUGO_VERSION: "0.167.0"
        run: |
          curl -sSfL -o /tmp/hugo.tar.gz \
            "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz"
          tar -xzf /tmp/hugo.tar.gz -C /tmp hugo
          sudo install -m 0755 /tmp/hugo /usr/local/bin/hugo
          hugo version

      - name: Install build dependencies
        run: npm ci

      - name: Production build and output rules
        run: (cd ../strata && ./scripts/validate-site.sh "$GITHUB_WORKSPACE")
EOF

# site README
cat > "$OUT/README.md" <<EOF
# ${NAME}

Site repository. Content and configuration live here; the layout comes from
the Strata Hugo theme.

## Development

Hugo compiles the theme's CSS in-process and, since 0.161.0, runs the
Tailwind v4 CLI through node. Install the build dependencies once:

\`\`\`sh
npm install
\`\`\`

Then build or serve through npm, which puts node_modules/.bin on PATH — that
is how Hugo finds the tailwindcss script:

\`\`\`sh
npm run dev      # hugo server -D
npm run build    # hugo --minify
\`\`\`

The required security.exec and security.node sections are already in
\`config/_default/hugo.toml\`.

Article Markdown uses leaf-bundle directories:

\`\`\`sh
hugo new ingredients/a-slug
\`\`\`

That creates \`content/ingredients/a-slug/index.md\`. The bundle organises the
Markdown only: images live separately at \`assets/images/ingredients/a-slug/\`.
Use the theme's
\`place-image.sh\` to lint and place them.

Run the local server (the go.mod replace points at the theme checkout):

\`\`\`sh
hugo server -D
\`\`\`

Validate against the theme checkout before deploying:

\`\`\`sh
(cd /path/to/strata && ./scripts/validate-site.sh /path/to/$SLUG)
\`\`\`

\`.github/workflows/validate.yml\` runs that same check on every push and
pull request, so the output rules gate deploys instead of depending on a
developer remembering the command.

When the theme publishes a release tag, remove the \`replace\` line from
\`go.mod\` and pin the tag with \`go get\`.

## Structure

- \`content/\` — Markdown leaf bundles and section indexes; no new image files
- \`assets/images/\` — all production image sources, organised by section/page
- \`config/_default/\` — site configuration (includes the Strata taxonomy contract)
EOF

printf 'ok   scaffolded %s\n' "$OUT"
printf 'next: hugo server -D --source %s\n' "$OUT"

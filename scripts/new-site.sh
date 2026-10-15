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
MODULE_VERSION="v0.0.0"

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
  "$OUT/static"

# config/_default/hugo.toml — nothing beyond the theme contract and the
# site's own authored settings
cat > "$OUT/config/_default/hugo.toml" <<EOF
baseURL = "https://${DOMAIN}/"
defaultContentLanguage = "en"
title = "${NAME}"

enableRobotsTXT = true
summaryLength = 30
enableEmoji = false

[module]
  proxy = "direct"

  [[module.imports]]
    path = "example.com/strata"

[module.hugoVersion]
  extended = true
  min = "0.161.0"

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
languageCode = "en"
languageName = "English"
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
# section/slug` creates a page bundle content/section/slug/index.md; the
# image resolver and place-image.sh both expect the bundle layout
mkdir -p "$OUT/archetypes/default"
cat > "$OUT/archetypes/default/index.md" <<'EOF'
---
title: "{{ replace .File.ContentBaseName "-" " " | title }}"
date: {{ .Date }}
draft: true
tags: []
series: []
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

for dir in about contact privacy-policy terms; do
  mkdir -p "$OUT/content/$dir"
  title=$(printf '%s' "$dir" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
  cat > "$OUT/content/$dir/_index.md" <<EOF
---
title: "$title"
---
EOF
done

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
  "display": "standalone"
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

# go.mod pins the theme version; the replace keeps local development
# working before the theme tag exists
cat > "$OUT/go.mod" <<EOF
module example.com/${SLUG}

go 1.22

require example.com/strata ${MODULE_VERSION}

replace example.com/strata => $ROOT
EOF

# package.json — Hugo 0.161.0+ runs the TailwindCSS CLI through node, so the
# build needs an npm install. `npm run build` / `npm run dev` put
# node_modules/.bin on PATH, which is how Hugo finds the tailwindcss script.
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
  }
}
EOF

# .gitignore
cat > "$OUT/.gitignore" <<'EOF'
resources/
public/
node_modules/
.DS_Store
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
`config/_default/hugo.toml`.

Articles are page bundles:

\`\`\`sh
hugo new ingredients/a-slug
\`\`\`

That creates \`content/ingredients/a-slug/index.md\`. Images for the article
live at \`assets/images/ingredients/a-slug/\`; use the theme's
\`place-image.sh\` to lint and place them.

Run the local server (the go.mod replace points at the theme checkout):

\`\`\`sh
hugo server -D
\`\`\`

Validate against the theme checkout before deploying:

\`\`\`sh
(cd /path/to/strata && ./scripts/validate-site.sh /path/to/$SLUG)
\`\`\`

When the theme publishes a release tag, remove the \`replace\` line from
\`go.mod\` and pin the tag with \`go get\`.

## Structure

- \`content/\` — page bundles and section indexes
- \`assets/images/\` — source images, organised by section
- \`config/_default/\` — site configuration (includes the Strata taxonomy contract)
EOF

printf 'ok   scaffolded %s\n' "$OUT"
printf 'next: hugo server -D --source %s\n' "$OUT"
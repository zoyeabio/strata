---
title: "Installation"
description: "Module setup, the taxonomy contract, and your first build."
keywords: ["installation", "hugo", "setup"]
weight: 10
---

## Requirements

- Hugo **0.161.0 or later**, Extended edition (tested on 0.167.0).
- Node.js 20 or later, with npm. Hugo runs the Tailwind CSS v4 CLI through
  node; the standalone binary Hugo used to call directly was dropped in
  0.161.0.
- Go 1.22 (only needed for Hugo Modules)

## Hugo Module (recommended)

Before the theme has a published release tag, mount it from a checkout with
a `replace`:

```toml
[module]
  proxy = "direct"

  [[module.imports]]
    path = "github.com/zoyeabio/strata"
```

```go
require github.com/zoyeabio/strata v0.1.0

replace github.com/zoyeabio/strata => /absolute/path/to/strata
```

Then run:

```sh
hugo mod tidy
```

Once a release tag exists, remove the `replace` and pin the version with
`go get github.com/zoyeabio/strata@v0.1.0`.

## Git clone

Clone this repository into `themes/strata` and set `theme = "strata"`.

## Taxonomy contract (required)

Strata resolves article tag links and series navigation through Hugo's
`GetTerms`. That reads the site's taxonomy configuration, so the site must
declare both taxonomies:

```toml
[taxonomies]
  series = "series"
  tag = "tags"
```

Hugo does **not** inherit `[taxonomies]` from a theme, and a missing
declaration does not fail the build — tag links or the series nav simply
stop appearing. `scripts/validate-site.sh` fails when either entry is
missing.

## New site from the scaffold

```sh
./scripts/new-site.sh \
  --name "Example" --slug example \
  --domain example.com --accent "#295f8f" \
  --sections "journal,resources" \
  --out ../example
```

The scaffold writes the minimal site layer the theme consumes: config with
the taxonomy contract, sections and menus, archetype, content skeleton,
image directories, static files, `go.mod`, `.gitignore` and a site README.
Place images with:

```sh
./scripts/place-image.sh --section journal \
  --post example-post \
  --file out/illustration-1.png --role illustration \
  --site ../example
```

`place-image.sh` lints the source width before copying: hero ≥1600px,
illustration ≥1280px, card ≥1200px, og exactly 1200×630. A failing lint
exits non-zero and writes nothing. It prints the front matter reference to
use in the page (the bare filename, for a page bundle at
`content/{section}/{slug}/index.md`).

## First build

1. Use the scaffold or set the taxonomy contract and module replace above.
2. Set `baseURL`, `title` and at least one menu.
3. Run `npm install` so the build can compile the stylesheet.
4. Run `npm run dev` (`hugo server -D`) — the home page should render
   header, footer and your first pages. npm puts `node_modules/.bin` on
   PATH, which is where Hugo finds the tailwindcss script.
5. Validate before deploying: `./scripts/validate-site.sh /path/to/site`
   (run from a theme checkout, or adjust the path) builds your site in
   production mode against the theme and checks output rules.

## Upgrading

While on the `replace` flow, pull the theme checkout and re-run the
validators. Once a release tag exists, `hugo mod get -u
github.com/zoyeabio/strata && hugo mod tidy` pins the new version, then
rebuild and run the validator.

Bumping Hugo changes how the stylesheet is compiled. Below 0.161.0 Hugo
calls the standalone Tailwind binary directly; from 0.161.0 it runs the
npm CLI through node. A site that moves across that line needs `npm
install` and the `security.node` block added to its config — the scaffold
writes both, and a hand-built site should copy that section from
`scripts/new-site.sh`.

The theme compiles its CSS in-process from `assets/css/` sources on every
build. The site config must allow the compiler under `[security.exec]`
and grant the addon its node policy under `[security.node]`; Hugo does not
inherit either block from a theme, so both must live in the site config
alongside the taxonomy contract above.

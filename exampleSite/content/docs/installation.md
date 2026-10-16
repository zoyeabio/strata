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

The theme is published at `github.com/zoyeabio/strata`. In your site's
`config/_default/hugo.toml`:

```toml
[module]
  proxy = "direct"

  [[module.imports]]
    path = "github.com/zoyeabio/strata"
```

Then run:

```sh
hugo mod tidy
```

Pin a release so an upgrade is an edit you make rather than one that happens:

```sh
go get github.com/zoyeabio/strata@<tag>
```

To work against a local checkout instead, add a `replace`. It wins over the
required version, so that version does not need to exist:

```go
require github.com/zoyeabio/strata v0.0.0

replace github.com/zoyeabio/strata => /absolute/path/to/strata
```

Your own site's module path is a separate thing: the scaffold writes
`module example.com/<slug>` there, which is Go's reserved documentation
domain and is never fetched — the host for a site you have not pushed yet is
not the theme's to choose.


## Git clone

Clone this repository into `themes/strata` and set `theme = "strata"`.

## Taxonomies

Strata resolves article tag links and series navigation through Hugo's
`GetTerms`. A content site enables those features explicitly:

```toml
[taxonomies]
  series = "series"
  tag = "tags"
```

For a compact site that needs neither feature, disable Hugo's implicit
taxonomies with an empty table:

```toml
[taxonomies]
```

Hugo does **not** inherit this table from a theme. Omitting it is different
from leaving it empty: omission enables Hugo's default `tags` and `categories`.
`scripts/validate-site.sh` accepts the enabled and explicitly disabled modes,
and rejects an omitted table or a `tag`/`series` mapping Strata cannot resolve.

`disableKinds = ["taxonomy", "term"]` also suppresses those output kinds, but
the empty table is clearer when the site does not use taxonomy data at all.

## New site from the scaffold

```sh
./scripts/new-site.sh \
  --name "Example" --slug example \
  --domain example.com --accent "#295f8f" \
  --sections "journal,resources" \
  --out ../example
```

The scaffold writes the minimal site layer the theme consumes: config with
tags and series enabled, sections and menus, archetype, content skeleton,
image directories, static files, `go.mod`, `.gitignore` and a site README.
Place images with:

```sh
./scripts/place-image.sh --section journal \
  --post example-post \
  --file out/illustration-1.png --role illustration \
  --site ../example
```

`place-image.sh` lints the source width before copying: hero ≥1600px,
illustration ≥1600px, card ≥1200px, og exactly 1200×630. A failing lint
exits non-zero and writes nothing. It prints the front matter reference to
use in the page. For `content/{section}/{slug}/index.md`, the file itself is
stored separately at `assets/images/{section}/{slug}/{filename}` and the
printed reference is the bare filename.

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

With a pinned module, `hugo mod get -u github.com/zoyeabio/strata && hugo mod
tidy` moves the version, then rebuild and run `./scripts/validate-site.sh`.
On the `replace` flow, pull the checkout and re-run the validators instead.

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

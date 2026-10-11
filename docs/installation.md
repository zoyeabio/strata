# Installation

## Requirements

- Hugo **0.151.0 or later**, Extended edition (the version the theme is
  tested against; a lower floor is not claimed yet)
- Go (only needed for Hugo Modules)
- Node.js — only when you change theme CSS in a theme checkout

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
  --name "Probio Intel" --slug probiointel \
  --domain probiointel.com --accent "#295f8f" \
  --sections "ingredients,production,safety,quality" \
  --out ../probiointel
```

The scaffold writes the minimal site layer the theme consumes: config with
the taxonomy contract, sections and menus, archetype, content skeleton,
image directories, static files, `go.mod`, `.gitignore` and a site README.
Place images with:

```sh
./scripts/place-image.sh --section ingredients \
  --post probiotics-infant-colic \
  --file out/illustration-1.png --role illustration \
  --site ../probiointel
```

`place-image.sh` lints the source width before copying: hero ≥1600px,
illustration ≥1280px, card ≥1200px, og exactly 1200×630. A failing lint
exits non-zero and writes nothing. It prints the front matter reference to
use in the page (the bare filename, for a page bundle at
`content/{section}/{slug}/index.md`).

## First build

1. Use the scaffold or set the taxonomy contract and module replace above.
2. Set `baseURL`, `title` and at least one menu.
3. Run `hugo server` — the home page should render header, footer and your
   first pages.
4. Validate before deploying: `./scripts/validate-site.sh /path/to/site`
   (run from a theme checkout, or adjust the path) builds your site in
   production mode against the theme and checks output rules.

## Upgrading

While on the `replace` flow, pull the theme checkout and re-run the
validators. Once a release tag exists, `hugo mod get -u
github.com/zoyeabio/strata && hugo mod tidy` pins the new version, then
rebuild and run the validator. The theme's CSS ships precompiled; you never
run npm in a site that only consumes the theme.

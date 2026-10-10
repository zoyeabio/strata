# Installation

## Requirements

- Hugo **0.142.0 or later**, Extended edition
- Go (only needed for Hugo Modules)
- Node.js — only when you change theme CSS in a theme checkout

## Hugo Module (recommended)

In your site's `config/_default/hugo.toml`:

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

## First build

1. Declare the taxonomies above.
2. Set `baseURL`, `title` and at least one menu.
3. Run `hugo server` — the home page should render header, footer and your
   first pages.
4. Validate before deploying: `./scripts/validate-site.sh /path/to/site`
   (run from a theme checkout, or adjust the path) builds your site in
   production mode against the theme and checks output rules.

## Upgrading

`hugo mod get -u github.com/zoyeabio/strata && hugo mod tidy`, then rebuild
and run the validator. The theme's CSS ships precompiled; you never run npm
in a site that only consumes the theme.

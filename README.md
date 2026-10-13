# Strata

A content-first Hugo theme built to be shared across independent sites.

Strata keeps everything site-agnostic inside the theme — layout, components
and styling. Branding, copy, navigation and configuration stay in each site's
own layer, so one theme can serve several sites without forking.

**Status:** the rebuild is complete. The [exampleSite](exampleSite/) is the
theme's own demo, and its [documentation section](exampleSite/content/docs/_index.md)
describes shipped behaviour.

## Highlights

- Responsive image pipeline: WebP ladder, `srcset`/`sizes`, role-derived
  quality, SVG/GIF/animated-WebP pass-through
- Light/dark appearance applied before first paint, four colour schemes
- Zero external requests — no webfonts, no CDNs, no tracking
- Taxonomy navigation resolved through Hugo's `GetTerms`, never string concat
- JSON-LD (WebSite / WebPage / Article), Open Graph and Twitter cards
- Rebuild is byte-reproducible; validators gate every change

## Requirements

- [Hugo](https://gohugo.io) **0.161.0 or later**, Extended edition
- Node.js 20 or later, with npm — Hugo runs the Tailwind CSS CLI through node
- Go 1.22 (only needed for Hugo Modules)

## Installation

As a Hugo Module, in your site's `config/_default/hugo.toml`:

```toml
[module]
  proxy = "direct"

  [[module.imports]]
    path = "github.com/zoyeabio/strata"
```

Then run `hugo mod tidy`.

Alternatively, clone this repository into `themes/strata` and set
`theme = "strata"`.

Your site must declare the theme's taxonomy contract (Hugo does not inherit
this from the theme — see [the installation docs](exampleSite/content/docs/installation.md)):

```toml
[taxonomies]
  series = "series"
  tag = "tags"
```

## Example site

`exampleSite/` is the theme's own demo and its live documentation. Build it
against this checkout:

```sh
cd exampleSite && npm install && hugo --minify
```

Every page exists to exercise a feature, and the demo assets regenerate
from a single script with no third-party package:

```sh
python3 scripts/gen-example-images.py --out exampleSite/assets/images
```

A Lighthouse check ships with it, local only — there is no workflow for it,
so the scores are laptop numbers and are not CI numbers:

```sh
cd exampleSite && npm run build && npm run lighthouse
```

It needs a system Chrome or Chromium; LHCI finds one through
`chrome-launcher` instead of downloading its own ~150MB copy.

## Documentation

The docs live in the example site, as pages, so they are built and
validated with the theme rather than drift in a separate tree:

| Document | Contents |
|---|---|
| [installation](exampleSite/content/docs/installation.md) | Module setup, taxonomy contract, first build |
| [configuration](exampleSite/content/docs/configuration.md) | Site params, front matter keys, site hooks |
| [images](exampleSite/content/docs/images.md) | Image storage, ladder, cropping, roles |
| [typography](exampleSite/content/docs/typography.md) | Type scale, prose width, system fonts |
| [customization](exampleSite/content/docs/customization.md) | Colour schemes, CSS variables, custom CSS |
| [shortcodes](exampleSite/content/docs/shortcodes.md) | Shortcode reference and supported parameters |
| [sitemap](exampleSite/content/docs/sitemap.md) | The sitemap, robots.txt, what gets listed |

## Development

The theme repo carries its own gates. After any change:

```sh
# once — Hugo 0.161.0+ runs the Tailwind CSS CLI through node
npm install
./scripts/smoke.sh     # fixture contract assertions
./scripts/validate-theme.sh
./scripts/audit-partials.sh   # partial call-graph audit (missing/orphan)
./scripts/validate-site.sh /path/to/site   # e.g. your site checkout
./scripts/new-site.sh --name "My Site" --domain example.com --out ../mysite
./scripts/place-image.sh --section journal --post slug --file photo.png --role illustration --site ../mysite
```

CSS compiles in-process via `css.TailwindCSS` on every build — there is no
committed bundle. Component files carry their own `@layer` wrappers and the
concatenation order lives in `layouts/partials/head/head.html`.

## License

MIT — see [LICENSE](LICENSE).

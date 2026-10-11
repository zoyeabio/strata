# Strata

A content-first Hugo theme built to be shared across independent sites.

Strata keeps everything site-agnostic inside the theme — layout, components
and styling. Branding, copy, navigation and configuration stay in each site's
own layer, so one theme can serve several sites without forking.

**Status:** in development. The theme is being rebuilt file by file, and not
every component is available yet.

## Highlights

- Responsive image pipeline: WebP ladder, `srcset`/`sizes`, role-derived
  quality, SVG/GIF/animated-WebP pass-through
- Light/dark appearance applied before first paint, four colour schemes
- Zero external requests — no webfonts, no CDNs, no tracking
- Taxonomy navigation resolved through Hugo's `GetTerms`, never string concat
- JSON-LD (WebSite / WebPage / Article), Open Graph and Twitter cards
- Rebuild is byte-reproducible; validators gate every change

## Requirements

- [Hugo](https://gohugo.io) **0.151.0 or later**, Extended edition
- Go (only needed for Hugo Modules)
- Node.js (only needed when changing theme CSS — see Development)

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
this from the theme — see [docs/installation.md](docs/installation.md)):

```toml
[taxonomies]
  series = "series"
  tag = "tags"
```

## Documentation

| Document | Contents |
|---|---|
| [docs/installation.md](docs/installation.md) | Module setup, taxonomy contract, first build |
| [docs/configuration.md](docs/configuration.md) | Site params, front matter keys, site hooks |
| [docs/images.md](docs/images.md) | Image storage, ladder, focus, roles |
| [docs/typography.md](docs/typography.md) | Type scale, prose width, system fonts |
| [docs/customization.md](docs/customization.md) | Colour schemes, CSS variables, custom CSS |
| [docs/shortcodes.md](docs/shortcodes.md) | Shortcode reference and supported parameters |
| [docs/product-pages.md](docs/product-pages.md) | Product/ingredient pages (planned) |

## Development

The theme repo carries its own gates. After any change:

```sh
npm install            # once — Tailwind build for assets/css
npm run build:css      # rebuild assets/css/compiled/main.css
./scripts/smoke.sh     # fixture contract assertions
./scripts/validate-theme.sh
./scripts/validate-site.sh /path/to/site   # e.g. your site checkout
./scripts/new-site.sh --name "My Site" --domain example.com --out ../mysite
./scripts/place-image.sh --section journal --post slug --file photo.png --role hero --site ../mysite
```

Do not hand-edit `assets/css/compiled/main.css`; it is generated from
`assets/css/` sources and the smoke test fails when it is stale.

## License

MIT — see [LICENSE](LICENSE).

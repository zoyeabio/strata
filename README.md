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
- Light/dark appearance applied before first paint, seven colour schemes
- No implicit external requests — maps and AdSense are explicit site opt-ins
- Taxonomy navigation resolved through Hugo's `GetTerms`, never string concat
- JSON-LD graph (`WebSite` / `Organization` / `WebPage` / `BreadcrumbList` /
  `Article` / `Series` / `Person`), Open Graph and Twitter cards
- Rebuild is byte-reproducible; validators gate every change, including a front
  matter lint for the failures a build ships without complaining

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
    path = "example.com/strata"
```

Then run `hugo mod tidy`.

Alternatively, clone this repository into `themes/strata` and set
`theme = "strata"`.

Taxonomies are a site-level choice because Hugo does not inherit them from a
theme. Enable Strata's tag and series features explicitly:

```toml
[taxonomies]
  series = "series"
  tag = "tags"
```

Or explicitly disable taxonomy pages for a compact site:

```toml
[taxonomies]
```

Do not omit the table: Hugo then enables its implicit `tags` and `categories`
taxonomies. See the [installation docs](exampleSite/content/docs/installation.md).

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

`@lhci/cli` is not a committed dependency: npx fetches it on demand and the
version is pinned in the script. It drags in ~320 packages for a check that
runs once a week, so the example site's build dependencies stay at the four
Tailwind packages the theme actually needs.

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
| [security](exampleSite/content/docs/security.md) | Response headers, the strict CSP, Cloudflare limits |

## Development

The build steps, the four gate scripts and the conventions for templates,
CSS and commits are in [CONTRIBUTING.md](CONTRIBUTING.md). Two tools set up
a new site against this theme:

```sh
./scripts/new-site.sh --name "My Site" --domain example.com --out ../mysite
./scripts/place-image.sh --section journal --post slug --file photo.png \
  --role illustration --site ../mysite
```

## License

MIT — see [LICENSE](LICENSE).

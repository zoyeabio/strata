# Strata

A content-first Hugo theme built to be shared across independent sites.

Strata keeps everything site-agnostic inside the theme — layout, components
and styling. Branding, copy, navigation and configuration stay in each site's
own layer, so one theme can serve several sites without forking.

**Status:** in development. The theme is being rebuilt file by file, and not
every component is available yet.

## Requirements

- [Hugo](https://gohugo.io) **0.141.0 or later**, Extended edition
- Go (only needed for Hugo Modules)

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

## Site layer

The theme ships defaults under `config/_default/`. A site overrides them by
shipping files with the same names:

| File | Purpose |
|---|---|
| `hugo.toml` | site config, module imports, taxonomies, pagination |
| `menus.*.toml` | navigation |
| `languages.*.toml` | site title, tagline, description |
| `params.*.toml` | appearance and feature switches |

Nothing site-specific belongs in the theme.

## License

MIT — see [LICENSE](LICENSE).

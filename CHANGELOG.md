# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Entries follow the rebuild steps; each step is one browser-verified pass.

## [Unreleased]

### Added

- `config/_default/languages.en.toml` — site title, description, date format, RTL flag
- `layouts/_default/single.html` — title and content
- `layouts/_default/list.html` — title, content, weight ordering, pagination
  and a card collection
- `layouts/index.html` — home page title and content; the dead
  `home-{layout}` dispatch is gone
- `layouts/partials/page/page-collection.html` — renders pages as a grid or a
  row of cards, with an empty-state message
- `layouts/partials/page/card.html` — one card with title, date and summary,
  parameterised by `variant`
- `layouts/partials/page/pagination.html` — previous, `n / total` and next
- `layouts/partials/head/head.html` — charset, viewport, title, description,
  robots, canonical, RSS and JSON autodiscovery, fingerprinted appearance script,
  site `customCSS` loading, guarded favicons, `extend-head` site hooks
- `layouts/partials/frame/header.html` — brand from `site.Params.logo` with a
  plain-text title that never disappears when no logo is configured
- `layouts/partials/frame/menu.html` — one navigation tree for every breakpoint,
  marking the active item with `aria-current`
- `layouts/partials/frame/footer.html` — site identity, footer navigation and a
  copyright line that resolves the `{ year }` placeholder, falling back to
  `© {year} {site title}` when no copyright is configured
- `assets/js/appearance.js` — applies the stored or system colour scheme before
  first paint, toggling `class="dark"` on the document root
- `README.md`, `CHANGELOG.md`
- Tooling: `scripts/audit-partials.sh`, `scripts/diff-build.sh`

### Changed

- `layouts/_default/baseof.html` — document shell with `lang`, `dir` and
  appearance attributes; the head delegates to `partials/head/head.html`, the
  body opens with `partials/frame/header.html` and closes with
  `partials/frame/footer.html`
- Head, header, footer, home, list, article and shortcode templates are
  scheduled for sequential rebuild; see the build plan for the order.

### Removed

- All site-specific content, branding and copy
- Google Fonts and preconnect hints — the theme makes no external requests
- Unused configuration and feature switches
- Compiled CSS, JavaScript bundles, icon set and static assets
- Third-party bundled asset that no target site uses
- Validation scripts carried over from the previous codebase

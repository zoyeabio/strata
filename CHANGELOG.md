# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Entries follow the rebuild steps; each step is one browser-verified pass.

## [Unreleased]

### Added

- `config/_default/languages.en.toml` — site title, description, date format, RTL flag
- `layouts/_default/single.html` — title and content
- `layouts/_default/list.html` — title, content and child page links
- `layouts/partials/structure/head.html` — charset, viewport, title, description,
  robots, canonical, RSS and JSON autodiscovery, fingerprinted appearance script,
  site `customCSS` loading, guarded favicons, `extend-head` site hooks
- `assets/js/appearance.js` — applies the stored or system colour scheme before
  first paint, toggling `class="dark"` on the document root
- `README.md`, `CHANGELOG.md`
- Tooling: `scripts/audit-partials.sh`, `scripts/diff-build.sh`

### Changed

- `layouts/_default/baseof.html` — document shell with `lang`, `dir` and
  appearance attributes; head delegates to `partials/structure/head.html`
- Head, header, footer, home, list, article and shortcode templates are
  scheduled for sequential rebuild; see the build plan for the order.

### Removed

- All site-specific content, branding and copy
- Google Fonts and preconnect hints — the theme makes no external requests
- Unused configuration and feature switches
- Compiled CSS, JavaScript bundles, icon set and static assets
- Third-party bundled asset that no target site uses
- Validation scripts carried over from the previous codebase

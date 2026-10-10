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
- `layouts/partials/data/image-resource.html` — resolves an image reference
  (page bundle, asset path, `images/{section}/…`, `static/` fallback) and
  returns responsive variants from one shared ladder capped at four widths
  (480, 800, 1280, 1920 — further capped by the image role: `card` 800,
  `illustration` 1280, `og` 1200x630), encoded once at WebP q78 so the same
  width is never written twice
- `layouts/partials/media/image.html` — the `<img>` emitter: `srcset`, `sizes`,
  intrinsic `width`/`height`, `loading`, `decoding`, `fetchpriority`
- `layouts/partials/data/card-presets.html` — the single source of truth for
  `sizes` per card variant and for body images
- `layouts/_default/_markup/render-image.html` — inline markdown images join the
  same pipeline, loading lazily
- `layouts/partials/opengraph.html` — Open Graph and Twitter card tags without
  the Hugo internal templates, so `og:image` is a 1200x630 JPEG produced by the
  pipeline with an `alt` fallback of `Featured image for {title}`
- `layouts/partials/data/hero-image.html` — resolves the article hero image once
  per page (cached in page scratch), so the head preload and the hero `<img>`
  share one computation
- `layouts/partials/page/hero.html` — article hero figure: eager loading with
  `fetchpriority="high"`
- `layouts/partials/page/series.html` — series name and weight-sorted article
  list, marking the current page with `aria-current="page"`
- `layouts/404.html` — not-found page linking the first navigation menu item
  and the home page, with no hardcoded paths
- `layouts/_default/terms.html` — taxonomy overview that switches between a
  card grid and a plain list via `site.Params.taxonomy.cardView`
- `layouts/_default/term.html` — term page with article count, description,
  paged card collection and pagination
- `layouts/partials/page/term-card.html` — term card with an image served by
  the shared role=card pipeline and the same eager split as cards
- `layouts/partials/page/term-text.html` — plain term row for the non-card
  view
- `test/fixture/` + `scripts/smoke.sh` — a minimal module site and a build
  assertion script: resolver paths, srcset ladder, og tags, eager/lazy split,
  hero preload equality, taxonomy and 404 pages (18 assertions, non-zero exit
  on failure)

### Changed

- `layouts/_default/baseof.html` — document shell with `lang`, `dir` and
  appearance attributes; the head delegates to `partials/head/head.html`, the
  body opens with `partials/frame/header.html` and closes with
  `partials/frame/footer.html`
- Head, header, footer, home, list, article and shortcode templates are
  scheduled for sequential rebuild; see the build plan for the order.
- `layouts/partials/page/card.html` — renders `featureimage` with
  `featureimagealt` (defaulting to `Featured image for {title}`); the first
  `site.Params.eagerCardCount` cards (6 by default) load eagerly, the rest
  lazily with `fetchpriority="low"`
- `layouts/partials/page/page-collection.html` — passes each card its position
  in the collection so the eager/lazy split can be applied
- `layouts/partials/head/head.html` — emits social card tags through
  `partials/opengraph.html`
- `layouts/partials/data/image-resource.html` — passes animated WebP through
  untouched (ANIM chunk probe), honours `site.Params.disableImageOptimization`
  to emit original files only, and warns about unresolved references in
  `hugo server` builds; production builds stay silent
- File-header comments across the theme no longer cite planning documents that
  are not part of the repository; each partial now names its callers
- Module path is `github.com/zoyeabio/strata`
- `layouts/_default/single.html` — hero image, title, date and tag metadata,
  series navigation and content
- `layouts/partials/data/card-presets.html` — `hero` sizes preset for the
  article hero image
- `layouts/partials/head/head.html` — article pages preload the hero image
  (`imagesrcset`/`imagesizes` match the hero `<img>`)
- `layouts/partials/data/image-resource.html` — candidate paths fixed to
  `images/{pageDir}/…` then `images/…` (section-flat and per-page-directory
  assets both resolve; nested content directories keep their intermediate
  path); `http(s)` references pass through only when
  `site.Params.allowRemoteImages` is set; the animated-WebP probe also checks
  `content/{pageDir}/` for page bundles
- `layouts/partials/media/image.html` — an explicit `alt=""` (decorative image)
  is no longer replaced by the default alt text
- `layouts/partials/page/card.html` — no empty `card__media` wrapper when the
  featured image fails to resolve; summary length is configurable via
  `site.Params.cardSummaryLength` (default 160)

### Removed

- All site-specific content, branding and copy
- Google Fonts and preconnect hints — the theme makes no external requests
- Unused configuration and feature switches
- Compiled CSS, JavaScript bundles, icon set and static assets
- Third-party bundled asset that no target site uses
- Validation scripts carried over from the previous codebase

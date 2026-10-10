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

- `layouts/shortcodes/figure.html` + `layouts/partials/media/figure.html` —
  shadow of Hugo's built-in figure shortcode with the full built-in parameter
  surface (src, link, target, rel, alt, title, caption, attr, attrlink, class,
  width, height, loading) plus `quality` and `role`; caption structure matches
  the built-in (`title` as `<h4>`, `attr`/`attrlink` in a paragraph), alt falls
  back to the plainified caption, and the `<img>` goes through the shared
  pipeline like the markdown render hook's
- `layouts/shortcodes/content/article.html` — embeds another page's card
  inline (`page/card.html`, variant `inline`, always lazy); unknown links warn
  in `hugo server` and render nothing instead of failing the build;
  `showSummary` resolves shortcode → page front matter →
  `site.Params.list.showSummary`
- `layouts/shortcodes/content/list.html` — recent-pages list rendered through
  `page/card.html` (grid or row); fixes the broken partial reference that made
  `cardView=true` fail the build, and selects the branch by explicit
  `"true"` comparison so `cardView=false` cannot read as truthy
- `layouts/shortcodes/content/icon.html` — inlines an SVG from the site's
  `assets/icons/` (the theme ships no icon set; a missing file stops the build
  with its position)
- `layouts/shortcodes/interactive/email.html` — entity-obfuscated `mailto`
  link with no JavaScript and no footer script to depend on
- `layouts/shortcodes/interactive/cta.html` — CTA banner with optional icon
  (skipped with a dev warning when absent); colour utility parameters dropped —
  styling belongs to CSS
- `layouts/shortcodes/interactive/contact.html` — contact form with honeypot,
  live byte counter and fetch submit; element ids are scoped per instance so
  two forms on one page do not collide
- `layouts/shortcodes/interactive/carousel.html` — carousel whose slides run
  through the responsive pipeline (srcset/width/height, first slide eager),
  glob patterns matched against page resources then assets (leading slash
  trimmed), captions keyed by file name, self-initialising inline script
- `layouts/shortcodes/layout/multi-col.html` + `col-left`/`col-mid`/`col-right`
  — column grid with computed `--mgrid-*` CSS variables and a single class set
  (`mgrid` container, `mcol` with position modifiers)
- `test/fixture/content/section-a/shortcodes.md` — one page rendering all
  eleven shortcodes for the smoke assertions

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
- `layouts/partials/data/card-presets.html` — every `sizes` string is now
  computed from one parameter block (gap, padding ladder, container cap,
  prose width): viewport-dependent ranges use `calc()` so the declared width
  is exact at every breakpoint; the grid ladder no longer subtracts the gap
  twice, and the hero no longer declares 1088px from a 1024px viewport
- `layouts/partials/media/image.html` — a standalone `sizes` attribute is no
  longer emitted when there is no `srcset` to describe
- `scripts/smoke.sh` — 31 assertions (from 18): preload `imagesizes` equality,
  the computed grid formula, animated-WebP and GIF passthrough, the remote
  image in both states, series navigation, silent production builds, and
  whole-site `sizes` invariants (a fixed width always fits its `min-width`,
  no bare `100vw` fallback)
- `test/fixture/` — covers the grid card view, the `series` taxonomy, an
  animated WebP, a GIF and a remote image reference

- `layouts/partials/data/card-presets.html` — an `inline` preset (same media
  box as `row`) for cards embedded by the content/article shortcode
- `layouts/partials/data/image-resource.html` — accepts a `quality` input
  (default stays 78) for the figure shortcode's quality parameter
- `layouts/partials/media/image.html` — accepts `width`/`height` overrides so
  explicit figure dimensions win over the intrinsic variant size
- `layouts/partials/page/card.html` — accepts an `eager` override so embedded
  body cards stay lazy regardless of their collection index
- `scripts/smoke.sh` — 60 assertions (from 31): the figure surface (including
  a python check that `quality=` writes its own variant set), both list
  branches, icon/email/cta/contact/carousel output and the layout class set
- `test/fixture/` — a shortcodes showcase page and a site-level icon asset
- `layouts/shortcodes/interactive/carousel.html` — the instance id is the
  ordinal alone; the wall-clock suffix is gone, so two builds of the same
  tree produce byte-identical pages
- `scripts/diff-build.sh` — hash normalization requires a hex run to contain
  `[a-f]`: pure-digit runs (timestamps, phone numbers) stay visible to the
  zero-diff gate, lettered hashes still normalize
- `layouts/partials/data/card-presets.html` — the sizes ladder rungs equal
  the rendered padding (24 / 56 / 96 / 128 per side below 640 / 640–852 /
  853–1023 / 1024 and up), the hero gains the 853 rung, the container cap
  becomes 1024 and the 1280 rung rounds up in floating point (`math.Div`
  truncates integer division)
- `scripts/smoke.sh` — 61 assertions (from 60): two independent fixture
  builds must be byte-identical

### Removed

- All site-specific content, branding and copy
- Google Fonts and preconnect hints — the theme makes no external requests
- Unused configuration and feature switches
- Compiled CSS, JavaScript bundles, icon set and static assets
- Third-party bundled asset that no target site uses
- Validation scripts carried over from the previous codebase

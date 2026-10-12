# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Entries follow the rebuild steps; each step is one browser-verified pass.

## [Unreleased]

### Added

- Breadcrumb trail from a `page/breadcrumbs.html` partial mounted on
  single, list, taxonomy and term pages, gated by the table matching the
  page Kind with a page-level override that honours explicit `false`.
- Article byline: page `author` wins, site `[author] name` is the fallback,
  both gated by `showAuthor`.
- Seamless carousel loop: a hidden first-slide clone closes the track.
- Non-article singles render full width via `mainSections` (absent means
  every single is an article); shortcode card grids go 3-up from 853px
  like section lists.
- Rich footer bottom travels as one bar (menu, social, copyright).
- AdSense readiness: `ads` shortcode with a head loader that only ships
  on pages using it, `static/ads.txt` contract (check-build R11),
  `partials/cookie-consent.html` site hook, and an empty-article gate
  (R13). Theme `layouts/robots.txt` declares the sitemap (R14).
- Verifiable authorship: schema `Person` author with `sameAs`,
  `BreadcrumbList`, `Organization` with `@id`, plus `article:tag`,
  `article:section` and `twitter:site` meta.
- Accessibility: skip link, carousel arrow keys and reduced-motion
  guards, contact live region, AA contrast in every scheme (smoke-gated).
- `header.layout = "smart"`: sticky header that hides on scroll down and
  reveals on scroll up (10px hysteresis, always visible near the top).
- Mobile disclosure menu below 853px with nested submenus (attached via
  `parent` identifiers); desktop keeps the row with hover-free dropdowns.
- `b2b` colour scheme (deep navy) for trade sites.
- Rich footer from the `[footer]` table: company, quick-links, legal and
  contact columns, social icon row (site `assets/icons/`, name fallback),
  Dark/Light switcher and scroll-to-top button. Without the table the
  footer is byte-identical to before (identity, menu, copyright).
- Previous/next links to the neighbouring articles of the same section, from
  Hugo's `PrevInSection` / `NextInSection`, gated by `[article] showPagination`
  with a per-page `showPagination` override. A lone article prints nothing.
- Section banner: `[list] showHero` lifts the section's `featureimage` above
  its title, on the shared hero block with the same fixed-height crop and the
  same preload as an article hero. A section without a `featureimage` keeps
  the header rhythm; a page-level `showHero` wins either way.

### Changed

- Article hero crops to a fixed `--page-hero-height` (200 / 260 / 300px by
  breakpoint) instead of letterboxing at its native ratio, so an image of any
  aspect fills its frame.
- `--article-hero-height` → `--page-hero-height` and `.article-hero` →
  `.page-hero`: the block is shared by article and section pages now, so the
  names were too narrow. Same crop, same token values.
- Section, taxonomy and term bodies ride the full content column too.
  `.page-content` carries the lift, so the 720px reading measure no longer
  applies to any landing page — only to article prose.
- The logo is bigger: `--brand-logo-height` 48 → 80px and the header bar
  grows to match (`--header-bar` 56 → 92px, so the mobile panel still clears
  the header). A 48px mark in a 56px bar read as postage-stamp small.
- Related content renders as a lazy card grid instead of a plain link list.
- Share buttons are 44×44 icon tiles instead of outlined pills; the label
  moves to `aria-label` and the theme now ships `email` and `whatsapp` icons.
- The 1px rules above the related grid and the adjacent-article block are
  gone. Both sections separate by their own 28px space, which is what the
  "Related" heading already needed — the rules sat flush against the share
  tiles and the card images and read as noise.
- Breadcrumbs show ancestors only — Home, then each parent up to the
  section — since the current page is the `<h1>` beside the trail and would be
  a crumb with no destination. A crumb takes its menu entry's name over the
  page title, so a long section title no longer ships as one crumb; the
  JSON-LD `BreadcrumbList` keeps the current page, which search engines want.
  Nothing renders when nothing sits above Home.
- `check-build.sh` and `place-image.sh` accept `--environment`, so a build made
  for a non-default environment is checked against the same config overlay Hugo
  used instead of a silently misassumed one.

### Fixed

- Docs no longer claim Hugo ignores a theme's `config/_default/` — it merges it
  deep, with a site value winning per key. The defaults still live in the
  theme's root `config.toml`, which is a choice now that the real limit is
  documented, not a limit that forced it. The environment-overlay claim was
  wrong the other way round: the scripts read `config/production/` too.
- Comment indentation in `page/share.html` and `page/page-collection.html`.

- Stylesheet pipeline is now Hugo-native: `head.html` concatenates the
  `@layer`-wrapped CSS sources in cascade order and compiles them
  in-process with `css.TailwindCSS` (deferred), minified and fingerprinted
  as before. `assets/css/compiled/main.css`, `package.json` and
  `package-lock.json` are gone — no npm anywhere. Builders need the
  standalone Tailwind v4 CLI on PATH plus `[security.exec]` covering it in
  site config (both documented in README and the scaffold, which neither
  can inherit from the theme). Verified byte-equivalent output on the demo
  and one production site.
- Card preset parameter renamed `variant` → `preset`, matching
  `data/card-presets.html` (CSS classes `card--grid/row/inline`
  unchanged).
- Card summaries are no longer truncated in the template: `card.html` emits
  the plainified summary whole and the CSS 3-line clamp owns the cut, so
  CJK and long summaries behave the same. `cardSummaryLength` is gone.
- Social tags match the page kind: empty image refs no longer fall back to
  `static/` (which resolved to the bare site root in `og:image`), and
  `article:*` times are gated on `og:type=article`. New R10 rule in
  `check-build.sh` pins both, including `name=` Twitter tags; it fails on
  pre-fix output.
- Dropped the `templates.Defer` call: with an empty body it deferred
  nothing, and the pipeline scans `@source` files directly so render order
  is irrelevant.   Docs now state the Hugo ceiling (< 0.161.0, where the
  standalone binary stops working).
- Landing pages lift the prose measure entirely, paragraphs included. The
  720px cap is for long-form reading; on a landing page it only leaves dead
  air at the right edge (`docs/typography.md` states the split).
- Row and inline cards keep the grid card's 16:9 thumbnail at a fixed
  240px column. The old `aspect-ratio: auto` let a portrait source set the
  height of the whole row; the image's own size no longer drives layout.
  The two columns only exist when there is media, so a list of imageless
  pages stays a single column instead of opening a void beside the title.
- `content/list` shows each page's summary by default; `summary=false`
  suppresses it. A list card reads as a card again (title, date, summary).
- Carousel indicators overlay the bottom of the image as a row of bars
  instead of taking a bar out of the layout; the controls now follow the
  slides in DOM order. A captioned carousel moves the dots to the top so
  neither hides the other.
- Header: logo 28px → 40px, nav links 16px/600, and the nav plus the action
  buttons sit as one group at the right (an auto margin, not the even spread
  of `justify-content: space-between`), with the gap tightened to 12px.
- Footer: the social group takes the right of the bottom bar and each link
  is a filled 44px tile (8px radius, 22px glyph) that reads on hover instead
  of a bare outlined glyph. The theme now ships `linkedin`, `facebook`,
  `instagram`, `moon` and `sun` icons a site can override by name.
- The appearance switch is an icon button: both scheme glyphs ship inline
  from `assets/icons/`, the moon hides via a source-order-gated rule, and
  `appearance.js` drives it with `data-effective` plus a scheme-named label.
- The contact form fills its content column. The 640px cap left a dead
  quarter of the page on a 1024px column and made the two-column field row
  twice as narrow as the address column above it.
- `check-build.sh` R5 counts one image per *carrier group* and collapses a
  candidate that is a subset of another, so a hero `<img>` preloaded through
  an `<link>` counts once instead of twice. R8 also catches a bare attribute
  (`href` with no `=`), which the old `href=["']` pattern skipped.
- The image pipeline and the build thresholds are config, not code: the
  variant ladder, role caps, WebP quality, social preview size, the page
  image budget and the per-role minimum source width live in the theme's
  root `config.toml` under `[params.image]` and `[params.build]`.
  `image-resource.html` reads them with its previous hardcoded values as
  fallbacks, and a site overrides a single key in its own `params.toml`;
  before this the numbers lived only in the template. `scripts/lib/build_config.py` resolves
  the same file pair for `check-build.sh --site` and
  `place-image.sh --site`, so a threshold you change in config is the
  threshold the gate checks. `validate-theme.sh` asserts the config reaches
  a consuming site; `smoke.sh` asserts the merge keeps an override scoped
  to the keys it sets.

### Fixed

- `assets/css/components/card.css` — `.card__summary` now pairs the
  standard `line-clamp: 3` with a `max-height: calc(3lh)` hard cap.
  Chromium without legacy `-webkit-box` computes even inline
  `display: -webkit-box` as `flow-root`, so `line-clamp` alone only limits
  height without paint-clipping and a 4th line bled to the card edge;
  the `lh`-based cap guarantees exactly 3 lines (compiled CSS rebuilt).

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
- `package.json` — npm build chain for the stylesheet: Tailwind CLI,
  `@tailwindcss/typography`, `@tailwindcss/forms` and `tailwindcss` itself
  (`tailwind-scrollbar` deferred until a scrollbar consumer exists);
  `build:css` writes the committed `assets/css/compiled/main.css`
- `assets/css/main.css` — Tailwind v4 entry: `@source inline()` allowlists the
  nine utility classes the templates use (comment text can no longer emit dead
  utilities), `@theme` pins the system font stacks and moves the breakpoints
  to the 640 / 853 / 1024 / 1280 ladder, and the `strata-base`,
  `strata-components`, `utilities`, `strata-overrides` layer order is declared
  once
- `assets/css/base/` — `palette.css` (neutral surfaces, text and state tokens
  with a full dark inversion plus `color-scheme`), `reset.css` (the framework
  padding container `--site-gutter` 24/56/96/128 capped by `--site-content`
  1024 on header/main/footer, body typography, links, `code`/`pre`/`table`),
  `typography.css` (heading scale with `text-wrap: balance`), `prose.css`
  (17px body at 1.7 line height, 18px from 1280px, 720px measure, mapped
  `--tw-prose-*` tokens) and `a11y.css` (focus ring, reduced motion)
- `assets/css/components/` — site header/footer, page header/pagination/404,
  cards and collections (1/2/3-column grid, 200px row thumb, line-clamped
  summary), article and hero, series list, taxonomy term cards and text list,
  carousel (indicator strip, 44px controls, caption overlay), contact form,
  CTA banner, figure captions, multi-column grid and shortcode embeds
- `assets/css/schemes/` — four colour schemes (`strata-default` blue,
  `strata-slate`, `strata-forest`, `strata-ocean`), each defining the seven
  `--site-*` variables for light and dark
- `layouts/partials/head/head.html` — loads the active scheme (from
  `params.colorScheme`, default `strata-default`, `errorf` on a missing file)
  concatenated ahead of the compiled bundle, minified and fingerprinted as
  one stylesheet
- `layouts/_default/single.html`, `list.html`, `layouts/index.html` — body
  containers carry the `prose` class so long-form text gets the typography
  treatment
- `scripts/smoke.sh` — 74 assertions (from 61): committed CSS must match a
  fresh `tailwindcss` build, exactly one fingerprinted stylesheet link per
  page, and the sizes-ladder rungs (720px measure, 200px row thumb, 2/3-column
  grids, gutter breakpoints, content cap) must exist in the shipped CSS
- Review pass — class-token coverage: smoke grew to 77 assertions; every
  class token the templates emit must be defined in the shipped CSS (both
  `.token` and `[class~="token"]` forms, dynamic `{{ }}` names contribute a
  prefix that must match). Inert tokens were resolved: menu/footer wrapper
  classes dropped or styled in place of utility classes, `pagination__link`
  position modifiers gone, `mcol--first/mid/last` and `mgrid--cols-*`
  modifiers gone, the honeypot's inline `display:none` moved to
  `contact-form.css`, the bare `article`/`term-collection` wrappers and the
  redundant `shortcode-list--rows` modifier deleted; the `gap-x-5` utility
  left the allowlist
- Review pass — sizes/CSS coupling: the card-presets comment pins the content
  cap to `--site-content`, the text preset gains the `(min-width:832px) 720px`
  rung (calc crosses the 720px prose cap at 832), smoke covers the missing
  56px/1024px gutter rungs, and `single.html` wraps its content in
  `with .Content` like the other entry templates
- Review pass — typography: the layer declaration drops the `utilities` name
  (Tailwind's earlier statement already fixed its position; naming it again
  suggested a false order), smoke gained three assertions that pin the real
  cascade — strata layers registered after Tailwind's, `pre` carrying mono
  13px, `.prose` carrying 720px rather than the plugin's 65ch — the term
  list takes the plan's terms-page rhythm (line-height 1.85, 16px from
  1280px), and both count badges settle on the plan's 12px chip size
- Review pass — follow-up: the text preset's high side gains the
  `(min-width:912px) 720px` rung with a calc below it (853–911 sits under
  the prose cap), the header and brand flex layout moves from utility
  classes into `site.css` (the allowlist is down to `sr-only prose
  not-prose`), and the layer-order assertion now parses every `@layer`
  statement per the spec instead of pattern-matching two of them
- `layouts/partials/head/schema.html` — JSON-LD graph: WebSite on the home
  page, WebPage on every rendered page and Article on dated content, with
  the social image reused from the Open Graph pipeline (the reference
  selection moved into `data/og-image-ref.html` so the two cannot drift);
  Product stays behind `schema.enableProduct` until the site-layer product
  template arrives
- `layouts/partials/data/image-resource.html` — a declared but unresolvable
  image now fails the production build (`errorf`) instead of being skipped
  silently; the development server still only warns, and a page
  with no image declared is not an error
- `layouts/partials/page/card.html` — the `extend-article-link.html`
  site hook is back at the card tail
- `scripts/check-build.sh` — shared output rules for the validators:
  referenced images exist, pipeline images carry `srcset` and a real `alt`,
  preload candidates are a subset of the page `srcset`, no orphan images
  (all text products scanned, srcsets expanded, favicons exempt), per-page
  image payload under 600KB, self-referential canonical (page 1
  pagination tolerated), the JSON-LD graph matches the page kinds, no dead
  links, no leaked dev placeholders, no `.DS_Store`
- `scripts/validate-theme.sh` — silent production build of the fixture plus
  `check-build.sh` theme mode; a draft page with an unresolvable image must
  fail the production build
- `scripts/validate-site.sh` — production build of any site against this
  theme checkout through `HUGO_MODULE_REPLACEMENTS` (the site tree is never
  written to) plus `check-build.sh` site mode; verified against strata-demo
- `test/fixture/content/section-a/missing.md` — now a draft, so the default
  build stays clean while `validate-theme.sh` proves the production error
  path
- Taxonomy contract review pass — the article tag links resolve through
  `GetTerms` (href equals the term's own URL, punctuation and all, and a
  tag without a built term page renders no link instead of a dead one), the
  series navigation resolves through `GetTerms "series"` and reads the term
  page's own list (the taxonomy key and the `strings.ToLower` match against
  front matter are gone), `validate-site.sh` asserts the host site declares
  the `tag` and `series` taxonomies (Hugo does not inherit a theme's
  `[taxonomies]`, so the contract is enforced at validation time rather than
  declared in a theme `hugo.toml` that would not be read), and smoke
  assertion 30 walks every tag and series link in the fixture output and
  requires a built page behind it
- `assets/lib/` (fuse, lite-youtube-embed, zoom — 60KB) deleted: no template
  referenced any of it; search returns when the search feature itself lands
- `theme.toml` — name, MIT licence, description, tags limited to shipped
  capabilities, `min_version = 0.142.0`
- `README.md` rewritten for public readers: verified highlights, the taxonomy
  contract up front, documentation index, development gates
- `CONTRIBUTING.md` — ground rules (no external requests, no placeholders,
  externalised config), the four validators, template layering, CSS rules,
  commit convention (behaviour changes ship with their assertion)
- `docs/` — installation (Module setup and the taxonomy contract),
  configuration (every consumed param, front matter key, site hook, plus
  the explicit list of accepted-but-unsupported keys), images (storage,
  resolution order, variant ladder, roles, pass-through rules),
  typography (measured scale, prose measure, system stacks), customization
  (four schemes, appearance switches, CSS variables), shortcodes (all
  twelve with their full parameter tables), product-pages (site-layer
  split, status not shipped)
- Smoke assertion 31: shortcode calls in the fixture must stay inside the
  parameter subset documented in `docs/shortcodes.md` — Hugo silently
  ignores unknown parameters, the whitelist turns the doc table into an
  executable contract
- Review pass — validator and preload fixes:
  - the hero preload `<link>` is emitted through `safeHTML`, because
    html/template URL-escapes the `imagesrcset` attribute (spaces become
    `%20`) and the browser would treat `url 480w` as one malformed URL,
    silently breaking the preload; `check-build.sh` R3 now reads `srcset`
    only from `<img>` tags, so a preload that points at no image on the
    page fails instead of passing vacuously
  - smoke assertion 30 fails when zero taxonomy links render (a site whose
    `GetTerms` silently returns nothing no longer looks green)
  - `validate-site.sh` checks the taxonomy values (`tags`, `series`) rather
    than the `key = value` pair, so a site that renames the singular key
    still validates
- `scripts/new-site.sh` — scaffold for a new site against the local theme:
  config with the taxonomy contract, menus, archetype, content skeleton,
  image directories, static files, pinned `go.mod` and a site README; no
  dead parameter keys
- `scripts/place-image.sh` — per-page image placement with a documented
  size lint (hero ≥1600, illustration ≥1280, card ≥1200, og exactly
  1200×630); failing lint exits non-zero without writing, successful
  placement prints the front matter reference; PNG/JPEG/GIF/WebP dimensions
  are read from headers with stdlib Python (no ImageMagick/sips dependency)
- Browser audit — mobile 390px layout fix: the header nav list now wraps
  (`flex-wrap: wrap`), so a site with many sections wraps into rows instead
  of pushing `Contact` and the page edge past the viewport
- Scaffold consistency review pass:
  - articles are now page bundles everywhere: the scaffold archetype is a
    directory archetype (`archetypes/default/index.md`), so `hugo new
    section/slug` creates `content/section/slug/index.md`, matching
    `place-image.sh` and the resolver's `assets/images/{section}/{slug}/`
    convention; docs/images.md states the bundle layout explicitly
  - the unpublished-module flow is explicit: scaffold `go.mod` pins the
    theme with a local `replace` until a release tag exists, and
    docs/installation.md documents both local and tagged flows
  - the Hugo floor is now the tested version, 0.151.0 (theme.toml,
    README, scaffold, docs); 0.142.0 was a forward-looking speculative number
    with no current basis
  - shortcode whitelist is generated from the implementation (scanning
    `.Get "key"` per template), so it cannot drift from the code;
    `compactSummary` is rejected rather than silently accepted
  - `llms.txt` lists real site URLs, `site.webmanifest` no longer declares
    an empty icon set, and the scaffold cleanup trap prints a message
    before removing a partial output

### Removed

- All site-specific content, branding and copy
- Google Fonts and preconnect hints — the theme makes no external requests
- Unused configuration and feature switches
- Compiled CSS, JavaScript bundles, icon set and static assets
- Third-party bundled asset that no target site uses
- Validation scripts carried over from the previous codebase

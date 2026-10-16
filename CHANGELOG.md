# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Strata is a standalone Hugo module: one theme, any number of brands. What
survives here is the set of decisions that would otherwise have to be
re-derived from the templates.

### Deliberate choices

- **No implicit external requests**, build time or runtime: no CDNs, webfonts
  or analytics. Fonts are system stacks. Maps, AdSense and site hooks are
  explicit, documented opt-ins rather than hidden theme traffic.
- **Config is data, not code, and it is the only place defaults live.** Every
  key the theme reads from `site.Params` has a default in
  `config/_default/params.toml` — the variant ladder, role caps, WebP quality,
  social preview size, page image budget, per-role minimum source width and the
  UI switches alongside. Hugo merges it underneath a site's config, and
  `scripts/lib/build_config.py` resolves that same file pair, so a threshold
  changed in config is the threshold the gate checks. The resolver understands
  Hugo's `params.toml` namespace and fails on a missing key instead of hiding it
  behind a copied fallback number. Templates no longer carry
  a `| default` for a key the config already defines, so there is one place to
  look and a site can never resolve a key to nothing. `validate-theme.sh`
  asserts the invariant by diffing every `site.Params.<key>` the templates read
  against the merged config. `[mainSections]` is the one deliberate omission:
  an empty slice is truthy in Go templates and `single.html` reads it through
  `with`, so shipping `mainSections = []` would flip "every single is an
   article" into "none is".
- **The reading measure is a parameter.** Article bodies cap at
  `params.readingMeasure` (default 720px), centred, text left-aligned. Before
  this, `components/article.css` lifted `.prose` to `max-width: none` and body
  copy rode the 1024px frame — 108 characters at 17px, against the 45–75 that
  the prose stylesheet's own comment asked for. The value ships as a CSS custom
  property in `<head>` before the stylesheet, so a site can set `800` or the
  string `"none"` without touching CSS. Responsive body-image `sizes` reads the
  same value, so a wider column does not silently receive a smaller candidate.
  The title block rides the same measure
  — a centred body under a full-frame h1 reads as a 152px misalignment at 1440,
  not as an intentional column. The hero stays full-frame: an image edge does
  not anchor the text grid. `.series` tracks the measure too, so one knob moves
  the whole column. The lift still exists for landing and
  list pages: short marketing blocks in a capped column only leave dead air at
  the right edge, so those keep `max-width: none`. `smoke.sh` guards both
  directions — that the `.prose` rule carries the measure and centring, and
  that the article body no longer carries the lift.

- **`exampleSite` carries overrides only.** Its `params.toml` keeps just the
  keys it sets differently from the theme, since the theme's own
  `config/_default/params.toml` is the reference and
  `docs/configuration.md` explains each key. Dropping the eight keys that
  duplicated a theme default — `colorScheme`, `autoSwitchAppearance`, `robots`,
  `list.cardView`, `article.showDate`, `article.showDateUpdated`,
  `article.relatedContentLimit`, `article.showPagination` — left all 162 built
  files byte-identical, which is what proves the theme's defaults hold.
- **Reproducible builds.** Two independent builds of the same tree are
  byte-identical, so a swapping id or timestamp cannot slip past every content
  assertion. The carousel instance id is the ordinal alone — the wall-clock
  suffix it once carried made every rebuild a diff.
- **The prose measure is for prose.** Sections, terms and the home page ride
  the full content column, so a landing page never leaves dead air at the right
  edge. The article cap itself is `params.readingMeasure`.
- **Colour is chosen, not written.** A site sets `params.colorScheme` and the
  theme resolves it to `assets/css/schemes/<name>.css` — seven variables strong,
  `--site-accent` plus `-strong`, `-soft`, `--site-surface-tint`,
  `--site-text-strong`, `--site-link` and `--site-ring`, each with a `:root.dark`
  twin. Seven palettes ship: blue (`default`, `slate`, `ocean`, `navy`), green
  (`forest`), wine and gold. The interface is the seven variables and nothing
  wider, so a brand change never reaches into a scheme file — a site picks a
  palette, and if none fits the theme grows one. Names are short colour
  descriptors, not product categories: a general theme should not carry a
  business context in a scheme name. The contrast floor is gate 39:
  white-on-accent and white-on-strong at 4.5:1, link on background at 4.5:1
  and ring on background at 3:1, both modes, over every file the glob finds
  — a new palette has to pass rather than merely ship.

### Behaviour notes

- **External content links open in a new tab.** A reader who follows a
  reference is looking it up, not leaving the article — so a link to another
  host gains `target="_blank" rel="noopener noreferrer"` and the article stays
  exactly where they were. Internal links and `mailto:` never do: site
  navigation has to stay in the tab, or every header click would spawn a new
  one. `externalLinksNewTab` turns the behaviour off. Scheme-relative `//host`
  counts as external too. Returning from an internal link needs no work: the
  browser's default `history.scrollRestoration` restores the reading position
  and no script in the theme sets it to `manual` or rewrites history.
- **Image output has a per-source ceiling.** A source may produce no more than
  four responsive candidates plus one fixed social-preview JPEG. The build
  gate reports total files, HTML, images and output size, then fails if role
  reuse or another transform expands that set beyond five files. The default
  ladder ends at 1600px, the shared hero/illustration cap, so no configured
  rung or demo-source pixels are unreachable; the separate caps remain site
  override hooks. Hugo replaces `[[cascade]]` arrays across config layers, so
  the docs now require any winning site array to retain the rule that prevents
  unused page-bundle originals from publishing.
- **The output gate judges the deployable build.** Site and fixture validation
  run `hugo --minify`; the parser accepts quoted and standards-compliant
  unquoted attributes, so canonical, schema, link and image checks need no
  site-specific minifier setting.
- **Unused bundle originals do not ship.** Generated sites set
  `cascade.build.publishResources = false`; resources touched by the image
  pipeline still publish, while source JPEG/PNG files do not sit beside their
  responsive WebP transforms and double the image payload.
- **Content layout and image storage are separate contracts.** Article Markdown
  uses `content/{section}/{slug}/index.md`, while every new image goes to
  `assets/images/{section}/{slug}/`. Bundle-local images remain readable only
  as a migration fallback; neither the scaffold nor `place-image.sh` creates
  them.
- **Top-level `summary` satisfies the article metadata contract.** The content
  lint now matches the templates and accepts it when `description` is absent;
  generated site archetypes expose the recommended SEO fields up front.
- **Unknown image roles fail the build.** A misspelled or site-specific
  `role=` no longer falls through to an arbitrary 1280px cap. Sites that add a
  role must map it to the shared image contract instead of receiving a
  plausible but unintended transform.
- **Content-image `sizes` follows the actual page width.** Figures, Markdown
  images and carousels use the reading measure on article pages and the full
  content frame on standalone pages. This changes only which existing ladder
  candidate the browser downloads; it creates no additional variants.
- **One image resolver.** `data/image-ref.html` serves cards, term cards,
  heroes and social output. Cards and heroes take `featureimage`, else a page
  bundle resource whose name contains `feature`, `cover` or `thumbnail` as a
  legacy migration fallback. Social
  falls back to `images[0]`, then `site.Params.defaultSocialImage`, and
  `featureimage` still beats `images` — the picture a page shows is the picture
   it advertises.
- **One keyword resolver.** `data/keywords.html` feeds
  `<meta name="keywords">` and schema `keywords` from one place —
  `params.keywords`, else `params.tags`. Items are trimmed, deduplicated and
  blank-dropped; a bare string splits on commas rather than iterating runes;
  and no source means no tag, since a theme must not invent keywords it was
  not given.

- **Site config wins over a theme language file.** The theme defaults used to
  sit in the theme's `languages.en.toml` under `[params]`. Hugo gives language
  config precedence over global site config, so the theme's own `description`
  quietly beat a site's — every page without its own description shipped the
  theme's string instead of the site's, in `name=description`, `og:description`
  and `twitter:description`. Only `isoCode` stays in the language file, because
  an ISO code belongs with the language it names.
- **Taxonomies are explicit but optional.** Hugo does not inherit a theme's
  `[taxonomies]`, so the site either enables Strata's `tags`/`series` features
  or supplies an empty table to disable Hugo's implicit taxonomies. The site
  gate accepts both modes, rejects an omitted table and catches mappings that
  the theme's `GetTerms` calls cannot resolve. Fragments are merged before that
  decision the way Hugo merges them — tables deep, `disableKinds` unioned — so a
  rule split across config layers cannot hide. The theme gate builds a generated
  taxonomy-free consumer to prove it emits neither term directories nor empty
  term markup.
  The assertion first requires the article artifact to exist, then checks both
  quoted and minified-unquoted class markup, so a missing file cannot pass as
  an empty taxonomy result.
- **Hugo 0.161.0+ compiles the stylesheet through node.** Hugo dropped the
  standalone Tailwind binary in 0.161.0, so the theme ships a `package.json`
  naming the four Tailwind packages and `scripts/new-site.sh` writes one into
  every scaffolded site; `npm run build` is what puts `node_modules/.bin` on
  PATH for Hugo. A site config needs `node` next to `tailwindcss` in
  `[security.exec]` plus a `[security.node].permissions` block for the addon —
  Hugo inherits neither from a theme. Along the same line Hugo dropped
  `HUGO_PARAMS_*` environment-variable overrides, so the fixture reaches its
  config-only states through the `config/remote/` and `config/nodesc/`
  environment overlays instead; and its default `baseURL` became absolute,
  which makes canonical and share URLs absolute too. Both are correct, so the
  share assertion pins the built canonical rather than the shape the URL takes.
- **The hero preload goes through `safeHTML`.** html/template URL-escapes the
  `imagesrcset` attribute, so a bare expression turned `url 480w` into one
  malformed URL and silently killed the preload.
- **Image roles keep their own aspect ratio.** The card is `16 / 9` and the
  hero is a fixed-height band (`--page-hero-height`), so a hero source is not
  "16:9 for SEO" — it is cropped to whatever the column width and that height
  give. `scripts/place-image.sh` never checked a ratio, only a minimum width.
- **A figure without `quality=` follows `[params.image].quality`.** The
  shortcode used to pin 78 before the call, so a site override reached the
  pipeline for markdown images and not for figures. The pipeline already had
  the right default; the shortcode just had to stop supplying one first.
- **Carousel slides get a real alt, and charts can stop being cropped.** `alts`
  is the same brace map as `captions`; a slide without one falls back to its
  caption, then to a positional label. `fit="contain"` fits the image inside
  the frame instead of `object-fit: cover`, so axes and legends survive. The
  frame class is assembled in a variable rather than written inside the
  `class` attribute, because the class-coverage gate tokenizes that attribute
  and reads `{{ }}` as class names.
- **Robots meta has a default, and page beats site.** Unset everywhere the
  theme now emits `index, follow, max-image-preview:large`; a page value
  overrides it, and a site value applies only where a page is silent. The
  template read `or site.Params.robots .Params.robots`, which made the site
  value win over the page— the opposite of what the docs promised.
- **The Article image list carries the hero variant too.** Google asks for a
  high-resolution 16:9 representative image where one exists. The widest hero
  variant is already built for the page, so the schema points at both the
  1200x630 preview and the hero with no new file, and deduplicates when they
  happen to be the same URL.
- **Summary truncation is CSS, not template.** The card emits the whole
  plainified summary; a 3-line clamp plus a `calc(3lh)` hard cap does the cut.
  Chromium without legacy `-webkit-box` computes even inline
  `display: -webkit-box` as `flow-root`, so `line-clamp` alone limits height
  without paint-clipping and a fourth line bled to the card edge.
- **Four config keys were declared that nothing read.** `[article] showSummary`,
  `[taxonomy] showHero`, `[taxonomy] orderByWeight` and `[taxonomy] showSummary`
  sat in `config/_default/params.toml` and in the "unsupported keys" section at
  the same time — shipped as defaults, documented as no-ops. `[taxonomy] showHero`
  was the telling one: the warning said a site `[list] showHero` did nothing
  while the supported table said it worked, and the template settles it in
  `data/hero-image.html` — the warning was wrong, not the table. `validate-theme.sh`
  only checks that every key a template reads has a default, never the other
  way, which is how four unread keys survived a config whose header promises
  "defaults for every key the theme reads".
- **Duplicate markup became partials.** The featured-image block was written
  twice, in `page/card.html` and `page/term-card.html` — the same 17 lines apart
  from class names and alt fallbacks — and now lives in `data/card-media.html`.
  The sort, paginate, collection and pager sequence was written twice, in
  `list.html` and `term.html`, and now lives in `page/paginated.html`; the page
  body block was written three times and now lives in `page/page-content.html`.
  Rendered output is unchanged apart from a couple of blank lines, so the moves
  are pure. The eager/lazy decision stays with the card: the media partial takes
  a plain bool, because `isset` cannot distinguish "caller did not pass this"
  from "caller passed false", and `content/article` passes false on purpose.
- **The example site shows every shortcode.** `interactive/contact` and
  `layout/col-mid` shipped undemonstrated, so a reader of `content/shortcodes.md`
  never saw either render. Both are live now, and the `multi-col` section names
  the hole `columns="4"` leaves: there is no fourth column shortcode, so a
   four-column grid repeats `col-right`, which renders the same `.mcol`.
- **Thin contrast margins were deepened, and navy stopped shadowing default.**
  Five dark-mode accents and six light-mode rings sat within 0.4 of the
  4.5/3.0 floors gate 39 enforces, so a one-step tweak would have pushed them
  below the line. Each was deepened on a hue-preserving lightness walk so a
  scheme still reads as itself: rings now land at 3.8-4.4 and dark accents at
  5.9-9.2, wine and gold gaining about 1.4 stops. navy was the case that
  needed no deepening and got one anyway: its dark accent and strong were
  byte-identical to default's (`#2f6fa5` / `#245a87`), so the two schemes were
  indistinguishable in dark mode. They are now derived from navy's own light
  hue, keeping the +6-lightness step every other scheme follows.
- **The theme has no shared ancestry in its code or docs.** The module path is
  `example.com/strata`, and no script, template, doc or changelog entry names
  anything it came from. `validate-site.sh` now holds the path in one `MODULE`
  variable and greps for it literally, instead of matching a `github.com/…`
  shape the new path cannot take, and `new-site.sh` drops `--org` for the
  same reason: the scaffold's module path is `example.com/<slug>`. The docs
  call the path a placeholder for wherever you actually host the theme, and
  note that `example.com` is Go's reserved documentation domain, so it is
  never fetchable and `go get` needs the real path.
- **The three column shortcodes are one line each.** `col-left`, `col-mid`
  and `col-right` render identical markup, so the `<div class="mcol">` moved
  to `shortcodes/mcol.html` and each shortcode passes its text along. The
  text is passed rather than the shortcode's `.` because Hugo refuses a
  closing tag unless the shortcode template itself reads `.Inner`.

- **`summary` is its own resolver, and it is visible.** `description` feeds the
  meta tag and `Article.description`; `summary` fed the same two as a fallback
  and appeared nowhere on the page. `data/summary.html` now renders it as a
  standfirst above the meta line, gated by `[article] showSummary` (default
  `true`) with the usual page-level override. The two stay separate resolvers:
  a page may set both with different wording, since one is written for a search
  snippet and the other for a reader. A standfirst is never generated — slicing
  the body would compete with a `<!-- more -->` cut, and a line a reader is
  meant to trust should be written rather than cut.
- **The author is an addressable person.** An `authorurl` on a page, or
  `[author] url` for a site, turns the byline into a link and emits
  `Person.url`; `author.links` remains `Person.sameAs`. The theme takes a URL
  rather than registering an `author` taxonomy: Hugo reserves the `author` key
  for authorship, so `author = "authors"` under `[taxonomies]` is accepted and
  then ignored, and no term page is ever built for it — a taxonomy that looks
  configured but produces nothing is worse than no taxonomy. Without a URL the
  byline stays plain text; the theme will not invent a destination.
- **Series is a graph node.** A page with a `series` term emits a `Series` node
  whose `hasPart` holds each member with its `position`, and the `Article`
  points back through `isPartOfSeries`. Members sort by `weight`, the same call
  `page/series.html` uses, so the graph and the on-page navigation cannot
  disagree about where a piece sits. Positions are pinned in `smoke.sh`, so a
  reorder shows up as a failure rather than as a wrong crawl.
- **The HTML trail and the JSON-LD trail name a page differently, on purpose.**
  A breadcrumb crumb takes its menu entry's short label, because a reader
  scanning a trail does not need "Feature Images, Formats and Optimization" to
  reach a page. The `BreadcrumbList` keeps the real title, because that field
  identifies the entity. They look like the same logic in two places, but they
  are two policies over the same data, so there is nothing to factor out — and
  unifying them would make the JSON-LD lose the title a search engine indexes.

### Gates

`smoke.sh` (fixture assertions, rebuilt and re-verified on every run),
`check-build.sh` (R1–R15), `validate-theme.sh`, `validate-site.sh`,
`validate-content.sh`, `audit-partials.sh` (missing/orphan partial call
graph), `new-site.sh` and `place-image.sh`. A behaviour change ships with its
assertion; the standing rules live in `CONTRIBUTING.md`.

`validate-content.sh` exists because the build cannot see a failure that
happened before it. An unknown front matter key, a missing description, a
`featureimage` without an alt and a `lastmod` earlier than `date` all build
cleanly, and the last one publishes as `dateModified` before `datePublished` in
the JSON-LD — a contradiction a search engine may read as a fabricated history.
The script reads the source instead of the output. Its list of allowed keys is
derived from the templates rather than written by hand, so there is one source
of truth and it cannot rot; it runs on `exampleSite` from `validate-theme.sh`
and on a consuming site from `validate-site.sh`. `test/fixture` is a gate
harness with deliberately minimal front matter, so it does not pass this lint
and is not judged by it. Hugo flattens a front matter `params:` map into
`.Params`; a rendered fixture pins that behavior, while the source lint applies
the same allowlist to nested and top-level spellings.

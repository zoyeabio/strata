# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Strata was rebuilt from scratch as a standalone Hugo module, file by file,
against zoyclaw v1.3.0 as the visual reference. Every step was a production
build plus a browser-verified pass at 1440 / 1280 / 390. The per-step log is
gone — what survives here is the set of decisions that would otherwise have to
be re-derived from the templates.

### Deliberate choices

- **No external requests**, build time or runtime: no CDNs, webfonts,
  analytics or third-party scripts. The reference theme shipped Google Fonts;
  Strata uses system stacks. No gate asserts this — it is a standing rule, not
  a check.
- **Config is data, not code, and it is the only place defaults live.** Every
  key the theme reads from `site.Params` has a default in
  `config/_default/params.toml` — the variant ladder, role caps, WebP quality,
  social preview size, page image budget, per-role minimum source width and the
  UI switches alongside. Hugo merges it underneath a site's config, and
  `scripts/lib/build_config.py` resolves that same file pair, so a threshold
  changed in config is the threshold the gate checks. Templates no longer carry
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
  string `"none"` without touching CSS. The title block rides the same measure
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
  business context in a scheme name. That closes the gap the reference theme
  left open: zoyclaw documented this same seven-variable contract in
  `site-network-skeleton.md` but never defined or consumed it, so per-site
  `colors.css` overrides set variables nothing read. The contrast floor is gate
  39: white-on-accent and white-on-strong at 4.5:1, link on background at 4.5:1
  and ring on background at 3:1, both modes, over every file the glob finds —
  a new palette has to pass rather than merely ship.

### Behaviour notes

- **One image resolver.** `data/image-ref.html` serves cards, term cards,
  heroes and social output. Cards and heroes take `featureimage`, else a page
  bundle resource whose name contains `feature`, `cover` or `thumbnail`, so a
  page bundle with a sibling `featured.jpg` needs no front matter key. Social
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
- **The taxonomy contract is enforced at validation, not declared.** Hugo does
  not inherit a theme's `[taxonomies]`, so a theme `hugo.toml` declaring them
  would be read by nobody. `validate-site.sh` asserts the host site declares
  `tags` and `series`; tag and series links resolve through `GetTerms`, so a
  tag with no built term page renders no link instead of a dead one.
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

### Gates

`smoke.sh` (fixture assertions, rebuilt and re-verified on every run),
`check-build.sh` (R1–R15), `validate-theme.sh`, `validate-site.sh`,
`audit-partials.sh` (missing/orphan partial call graph), `new-site.sh` and
`place-image.sh`. A behaviour change ships with its assertion; the standing
rules live in `CONTRIBUTING.md`.

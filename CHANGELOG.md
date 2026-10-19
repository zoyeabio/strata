# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Reference legal pages ship in the example site.**
  `content/privacy-policy.md`, `content/cookies.md` and `content/terms.md`
  are templates that leave every fact as `[TBD]`, so a site copies the
  shape instead of inventing the sections. The privacy policy names what a
  static site actually collects — contact form submissions, host server
  logs, cookies — and carries the ad personalization disclosure: the page
  URL and IP address a browser sends to Google, the four domains that set
  advertising cookies, Google's published nine-month and eighteen-month
  anonymization periods, and the controls a reader can use to opt out. The
  consent banner now links to the cookie notice and the privacy policy,
  both land in the footer legal menu, and `validate-theme.sh` pins the
  pair because check-build catches an empty href but not a link whose
  target is missing.

- **New sites start with legal stubs instead of blank pages.**
  `scripts/new-site.sh` writes the three legal pages as TODO stubs with a
  pointer to the example site's templates, so a privacy policy is not one
  of the pages a site ships empty by accident. The footer menu gains a
  Cookies entry next to Privacy and Terms.

### Fixed

- **check-build R11 reads ads.txt as records, not as a substring.** The old
  rule searched the whole file for the publisher ID's digit string, so the
  scaffold's commented-out stub line — `# google.com, pub-…` — passed as an
  authorization while the only real record sat inside a comment. The rule now
  parses records: blank lines and `#` comments are ignored, field 2 must be
  the bare `pub-<digits>` ID, and field 3 must be DIRECT or RESELLER, which
  are the two record types that authorize.

- **head.html only accepts a real policy line for the ad CSP check.** The
  old pattern matched `script-src … pagead2` anywhere in `static/_headers`,
  so a commented-out line or a `Content-Security-Policy-Report-Only` stance
  — the exact shape a "Report-Only first, then enforce" walkthrough
  produces — passed the check while the enforced policy still blocked the
  loader. The check now anchors at the `Content-Security-Policy:` header
  name, which excludes comment lines and the Report-Only variant (the colon
  must follow `policy` immediately).

- **The `ads` shortcode contracts on shape.** A `slot` that is not the
  dashboard's numeric ID and a `client` that is not a `ca-pub-…` (or
  `ca-host-pub-…`) publisher ID fail the build now, instead of serializing a
  garbage loader URL that only surfaces as a blank unit after deploy. The
  same shape is checked in `head.html`, so a malformed `[ads] client` cannot
  reach the loader line through the consent path either.

- **The legal templates no longer overstate what is off when personalization
  is off.** With Ad personalization disabled Google may still read
  non-personalized identifiers for frequency capping, fraud detection and
  aggregate reporting — the templates now say so. The withdrawal text drops
  the implication that an opt-out browser add-on keeps analytics running
  until you install it: withdrawing stops what the site loads on later
  pages, and Google-side retention stays where Google manages it (Ad
  Settings, My Activity). "No jurisdiction requires consent for necessary
  cookies" became the softer, true framing — regulators treat strictly
  necessary storage as exempt — and the banner links use `relLangURL`, so a
  language-prefixed site keeps working.

## [0.1.1] - 2026-10-17

### Added

- **New sites ship a validating CI workflow.**
  `scripts/new-site.sh` writes `.github/workflows/validate.yml`, which
  checks out Strata as a sibling directory pinned to the tag `go.mod`
  requires and runs `scripts/validate-site.sh` against the site on every
  push and pull request. The output rules then gate a deploy instead of
  depending on a developer running the command from a theme checkout, and
  the sibling checkout overrides the local `replace` path in the
  scaffold's go.mod.

- **check-build carries the hosting file ceiling as R16.**
  `[build] maxfiles` (20,000, Cloudflare Pages' free-tier limit; the paid
  tier raises it to 100,000) counts every file in the build output, not
  only images, so the artifact stays under the platform limit before a
  deploy refusal is the first thing that reports it.

- **place-image caps the source image size.**
  `[build] maxsourcekb` (12,000 KiB) rejects a source before it is copied
  into the site's assets. The pipeline already re-encodes at a capped
  width and one quality, so reader bytes are bounded; the cap bounds the
  source left in the repository and the time the build spends on it.

- **The theme declares its Hugo floor to the module loader.**
  `config/_default/hugo.toml` carries `[module.hugoVersion]` with
  `extended = true` and `min = "0.161.0"`, which `theme.toml`'s
  `min_version` never reached — galleries read that, the loader reads
  this. The floor is advisory by Hugo's design: an older version gets a
  "not compatible" build warning rather than a refused build, so the
  incompatibility surfaces instead of hiding.

- **A reference contact endpoint ships beside the shortcode.**
  `docs/contact-endpoint/` carries a copy-pasteable Cloudflare Worker that
  does what `docs/shortcodes.md` says the server must do: same-origin and
  body-cap checks before any parsing, `formData` with `.trim()`, honeypot
  answer-with-success, `TextEncoder` byte count, email regex, the
  `minFill ≤ now − ts ≤ 2 h` timestamp window when `form_ts` is non-empty,
  a `contact:{epoch}:{uuid}` KV key so messages sort and stay unique across
  workers, and best-effort forwarding. The JSON envelope `{success, error}`
  is spelled out because the client reads that shape. Rate limiting stays a
  stub the site owns; `wrangler.toml` ships too, with the comma-separated
  `ORIGINS` note that Workers vars cannot hold arrays.

- **A complete but replaceable default favicon set.** The module supplies
  one compact strata mark as SVG, ICO, Apple Touch, Android/PWA and Safari
  mask assets. Sites replace a same-named file under `static/` or override
  `partials/favicons.html`; the manifest remains site-owned because its
  name and product colours belong to the consuming site.

- **The docs gain a troubleshooting page for Hugo platform gotchas.**
  `docs/troubleshooting/` collects the behaviours that read as theme
  defects and the one-line config fixes each one has: future-dated pages
  that silently vanish, `pageRef` over bare URLs in menus, custom layouts
  that lose related articles and pagination, Markdown images wrapping in
  `<p>` by default, `content/list`'s `where` being a page field rather
  than a section name, the deprecated `languageCode`/`languageName` keys,
  and the module path being a separate thing from a site URL.

### Changed

- **AdSense is CSP-honest.** The `ads` shortcode's push call moved from an
  inline script to external `js/ads.js` behind an integrity attribute —
  the same pattern as `contact.js` — so enabling ads never asks
  `static/_headers` for `unsafe-inline`. The head loader now fails the
  build while no `script-src` allows `pagead2.googlesyndication.com`: an
  ad slot behind a blocking CSP ships blank, and that error belongs at
  build time rather than in a reader's console. `[ads] skipCspCheck`
  exists for hosts that apply response headers themselves, and the
  security docs carry a working ad-site `_headers` block plus Google's
  own caveat that only a nonce policy is officially supported.

- **Strata declares itself English-first.** The README, `theme.toml` and
  the search tokenizer state the Latin-script assumption — a non-Latin
  site supplies its own strings and search behaviour — instead of leaving
  a reader to discover it.

- **The mailto outlets are hardened end to end.** Every configured or
  authored URL passes through `partials/href.html`, which emits the whole
  `href` attribute so the `&#64;` stays a literal and cannot be
  re-escaped into useless text, and which reproduces the URL policy
  position used to get for free. JSON-LD drops `mailto:` entries outright.
  The scheme is matched case-insensitively — `MAILTO:` renders normalised
  instead of slipping through as a bare address — and the contact form
  gained a `cooldown` (default 10 s, per-instance, counted on attempt,
  failures included) plus a honeypot rejection and a `minFill` dwell
  window with the render instant travelling as `form_ts` for the
  server-side check. `docs/shortcodes.md` carries the server-side
  checklist; `security.md` states the boundary: obfuscation buys time, a
  rotatable alias behind the contact form is the durable answer.

- **The deprecated language keys are renamed where they are read.**
  `languageCode`/`languageName` become `locale`/`label` in the theme's
  `languages.en.toml` and in `new-site.sh`'s scaffold, so a scaffolded
  site stops printing Hugo's deprecation warnings. The value stays `en`:
  the templates read it into `<html lang>`, `og:locale` and the
  `content-language` meta, so the rename renders byte-identical output.

- **Clay's daytime ground is a faint warm white, not a yellow cream.**
  `--site-page-bg` moves from `#fbf1c7` to `#f7f4ec` — the same 44°
  warmth at s=41%, l=95% — raising every light-mode contrast pair, with
  `smoke.sh`'s 182 pairs still clearing their floors.

- **The `content/list` demo matches the docs** (`where="Type"`, not
  `where="Section"`), so a reader copying the demo learns what the
  reference page teaches.

### Fixed

- **Build thresholds from config now reach the check-build rules.**
  `scripts/lib/build_config.py` printed plain shell assignments, which its
  callers `eval`ed without exporting them. A python subprocess cannot see
  them through `os.environ`, so every threshold silently fell back to its
  hardcoded default: `[build] pageimageskb`, `[build] minwidth`,
  `maxfiles` and `maxsourcekb` were never honoured from a site's own
  config, and `R5`'s page budget was unconfigurable in practice. The
  assignments are exported.

- **A front matter `false` is no longer read as unset.** Hugo's `default`
  filter treats boolean `false` as missing, so a page that set
  `showSummary = false`, `cardView = false` or `orderByWeight = false`
  was overridden by the site default, and a sharing service's
  `"blank": false` (the one mailto needs) opened a new tab anyway.
  `paginated.html`, `share.html` and `content/article` resolve an
  explicit page value with `isset` instead.

- **The 404 page survives a URL-less first menu entry.** It now links the
  first main-menu item that carries a URL — a pure dropdown parent no
  longer crashes the build through `href.html`, which itself tolerates a
  nil URL instead of failing on `strings.TrimSpace`.

- **A quoted RFC3339 date is a date again.** `validate-content.sh` parses
  ISO 8601 datetimes — time zones, fractional seconds, `Z` — so a page
  dating itself `"2026-01-05T10:00:00+08:00"` is checked instead of being
  misreported as "lastmod without date" with every date rule silently
  skipped. Front matter triage also parses TOML (`+++`) pages, strips a
  UTF-8 BOM, and reports an unclosed `---` rather than skipping the page.

- **The smoke gate reports a missing stylesheet instead of dying.** The
  `ls | head -1` assignments sat under `set -o pipefail`, so an empty
  `css/` directory killed the script before its own failure branch could
  run; they now fall through to the assertion that names the problem.

- **The demo generator's `add` blend stops saturating to white.**
  `max(255, min(255, …))` clamped every lightened pixel to 255; the
  expression clamps to `[0, 255]`, so the dot and ring overlays in
  `hero-shortcodes`, `texture-weave` and `square-portrait` carry their
  soft edges again.

- **The search count reports every match.** The list still caps at ten
  rows, but the status line no longer claims a 47-match query has ten
  results.


## [0.1.0] - 2026-10-16

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
  theme resolves it to `assets/css/schemes/<name>.css`. A scheme is a table of
  anchors — `--site-page-bg`, the four text steps, `--site-accent` plus
  `-strong` and `-fg`, `--site-link`, `--site-ring`, `--site-ok` and
  `--site-error`, each with a `:root.dark` twin — and nothing wider. The
  decorative colours are derived from those anchors with `color-mix` in
  `palette.css`, so a palette file carries no surface or border scale of its
  own, and `palette.css` carries no literal colour at all: the anchors are the
  only colour values in the theme. Seven palettes ship, one per ground rather
  than one per hue: `default`, `navy`, `forest`, `wine`, `paper`, `clay`
  and `night`. Names stay short colour descriptors, not product categories —
  a general theme should not carry a business context in a scheme name. The
  floors are gate 39, which evaluates the derived colours rather than skipping
  them: text, link, ok and error at 4.5:1 on the ground, faint text and the
  focus ring at 3:1, white on the accent fills at 4.5:1, the selection pair at
  4.5:1, both modes, over every file the glob finds. A completeness check on
  the anchor set is the safety net for `palette.css` having no fallbacks to
  hide behind — a new palette has to earn its colour rather than merely ship it.

### Behaviour notes

- **Colours are derived, not declared.** A scheme used to carry every value it
  rendered with; it now carries anchors only, and `palette.css` derives the
  decorative set from them with `color-mix`. A palette file is a data table, so
  a new scheme inherits a coherent surface and border scale without anyone
  writing one. Structural colours mix from `--text` — 4%, 7%, 13% and 25% over
  the ground — which keeps panels and hairlines neutral whatever the brand hue;
  brand colours mix from `--site-accent` — 5% and 18% — so a tinted panel and a
  selection track sit in the same palette as the button they point to. The six
  ratios are declared once, in both mode blocks, and apply to every scheme.
  `--site-accent` was doing two jobs and one of them was unsatisfiable: it is a
  fill that must hold white text, and a text colour over the ground. In dark
  mode no value is dark enough to hold white and light enough to read against
  the ground, so the text usage moved to `--accent-fg`, backed by a new anchor
  `--site-accent-fg` set only in dark blocks and falling back to the accent in
  light. The 404 code, prose link hover, carousel hover, the a11y panel's
  checkboxes and `::selection` read it now. Gate 39 caught the default dark
  accent at 3.05:1 as text, below the 4.5:1 it is checked at.
  The set is seven palettes, one per ground: `default`, `navy`, `forest`,
  `wine`, `paper`, `clay` and `night`, replacing ten accent-only variants
  that varied hue without varying ground. Every palette clears the floors in
  both modes and keeps `ok` and `error` apart under deuteranopia, protanopia
  and tritanopia — paper dark and clay dark were the two that needed a
  lightness walk to get there.

- **External content links open in a new tab.** A reader who follows a
  reference is looking it up, not leaving the article — so a link to another
  host gains `target="_blank" rel="noopener noreferrer"` and a small arrow,
  so the article stays exactly where they were and the reader sees that it
  will. Internal links and `mailto:` never do: site navigation has to stay in
  the tab, or every header click would spawn a new one. The arrow is a real
   element rather than `::after` content, because assistive technology reads
   generated content and would otherwise announce "arrow" after every link, and
   it carries the text variation selector so it does not render as an emoji.
   The anchor also carries `class="link--external"`, which is the hook a site
   needs to style external links as a group — without it a site would have to
   reach through the marker with `a:has(.link__icon)`.
   `externalLinksNewTab` turns the behaviour and the marker off together.
  Scheme-relative `//host` counts as external too, as does any host other than
  the site's own — links between your own sites open new tabs. Returning from
  an internal link needs no work: the browser's default
  `history.scrollRestoration` restores the reading position and no script in
  the theme sets it to `manual` or rewrites history.
- **Anchors clear the sticky header.** An in-page link jumps its target to
  the top of the viewport, which is exactly where a sticky header sits, so a
  heading landed underneath it. The document now carries
  `scroll-padding-top: var(--header-bar)`, gated on
  `html:has(.site-header--smart)` so a static header gets no offset — it
  scrolls away, so the padding would just leave an empty band at the top.
  `--header-bar` moved from `.site-header` to `html`, because a scroll
  container cannot read a property defined on the element it is offsetting.
  It is the header's `min-height`, so a nav that wraps above 852px can still
  overhang the target.
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
  decision through the same `_merge` the config resolver uses — tables deep,
  every other key replaced by the higher-precedence layer and never unioned
  with it, because that is how Hugo resolves a key declared in two layers. A
  `disableKinds` split across `_default` and an environment therefore resolves
  to what the build actually disables, not to both layers' values added
  together. The theme gate builds a generated taxonomy-free consumer to prove
  it emits neither term directories nor empty term markup.
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
- **The theme publishes as a Hugo Module at a path that fetches.** `go.mod`
  declares `github.com/zoyeabio/strata`, so a site installs it the way
  Blowfish installs: one `[[module.imports]]` line and `hugo mod tidy`, with
  no `replace` and no local checkout. The same path carries the README, the
  example site, `new-site.sh`'s scaffold, the fixture and
  `validate-site.sh`'s single `MODULE` variable, which greps for it literally
  instead of matching a `github.com/…` shape. The theme's own ancestry stays
  unnamed: no script, template, doc or changelog entry says what it came
  from. What deliberately does not follow the published path is a *site's*
  module path — the scaffold still writes `example.com/<slug>`, Go's reserved
  documentation domain, because a site's host is not the theme's to choose,
  and `new-site.sh` ships no `--org` for that reason.
- **The four gates run on GitHub.** `.github/workflows/ci.yml` runs
  `smoke.sh`, `validate-theme.sh`, `validate-site.sh` and
  `audit-partials.sh` on every push and pull request, so "the gates pass"
  names a run rather than a laptop. It needs Hugo Extended, Node with `npm
  ci`, Python 3.11 for `tomllib` and PyYAML for the front matter lint — a
  dependency no document mentioned until the first run failed on it — and
  takes no third-party action beyond the official setup ones.
- **The Node floor is 22, and the first CI run is what found out.** The docs
  said "Node 20 or later" because Hugo 0.161 runs the npm CLI through node,
  but this Hugo also passes that node `--permission`, which Node 20 does not
  have: it answers `bad option:` and the stylesheet never builds. Nothing
  said so. The gate runs Hugo `--quiet`, the failure's whole message was in a
  file the EXIT trap deleted, and the run printed `exit code 1` and nothing
  else — measured locally under `nvm` before anything was guessed: Node 20
  fails, 22 and 23 build. `smoke.sh` now repeats a failed build without
  `--quiet` so the next silent failure speaks for itself, and the floor is
  22 in the README, both docs, both `engines` blocks, the scaffold's
  generated `package.json` (where npm warns at install time) and the
  workflow's `node-version` — which the run then proves instead of asserts.
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

 - **`extend-article-link.html` is not inside the card link, despite the name.**
   The docs called it "extra markup inside each card link", which is not what
   the template does: `page/card.html` calls it at the end of the `<article>`,
   after the summary, so it can hold block-level content — a tag chip, a byline,
   a badge. Restricting it to the link would have left nothing for the rest of
   the card to carry. The docs now say so explicitly, because the name suggests
   the opposite and a site copying a partial wants to know where the markup
   lands before it styles it. exampleSite demonstrates it with a tag chip.
 - **exampleSite implements every site hook, and ships a reference `customCSS`
   file.** The hooks were documented in a table and existed nowhere to copy
   from — a reader had to write `partials/extend-head.html` from a description
   of what the partial receives. `exampleSite/layouts/partials/` now carries all
   five, each with a header comment naming its caller, its context and whether
   it is cached, and each verifiable in the built output: the cached head hook
   carries a constant `theme-color`, the uncached one carries the page's own
   URL, so the difference between the two is visible rather than asserted.
   `assets/css/example.css` is the reference `customCSS` file and every rule in
   it styles markup the example emits through those partials. That pairing also
   records why `customCSS` needs no `!important`: the theme's rules live in
   `@layer`, a site's stylesheet does not, and unlayered wins at equal
   specificity.

   Two pre-existing page-level demos were no-ops and are corrected. `[list]
   showSummary` defaults to `false`, so `showsummary: false` on the docs index
   did nothing; the site now shows summaries on posts, and the docs index opts
   out of them on a page it has to stand alone. `page/breadcrumbs.html` renders
   only when a page has non-home ancestors, so `showBreadcrumbs: false` on a
   top-level page would never have been visible either and is gone. A demo that
   cannot be observed is not a demo, which is why the coverage gate reports
   undemonstrated keys as a warning rather than a failure.
 
 ### Gates


`smoke.sh` (fixture assertions, rebuilt and re-verified on every run),
`check-build.sh` (R1–R15), `validate-theme.sh`, `validate-site.sh`,
`validate-content.sh`, `validate-example.sh`, `audit-partials.sh`
(missing/orphan partial call graph), `new-site.sh` and `place-image.sh`.
 A behaviour change ships with its
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

`validate-example.sh` exists because coverage is not the same as correctness.
`test/fixture` proves the theme renders what it promises; `exampleSite` is what
a reader actually opens, and nothing kept the two in step. A shortcode could
ship with no live example, a site hook with no implementation to copy from, and
a hook the theme stops probing could leave a dead file in
`exampleSite/layouts/partials/` indefinitely. The script derives all three lists
from the theme's own tree — `layouts/shortcodes/`, the `templates.Exists`
probes, and the keys the templates read — so there is no hand-written inventory
to keep in step with the code. Shortcode and hook coverage fail; page-level
front matter key coverage is advisory, because some overrides have no sensible
page to demonstrate them on, and forcing one would mean writing content about
the feature rather than the product. It runs from `validate-theme.sh` as well
as standalone.

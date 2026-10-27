---
title: "Configuration"
description: "Site params, front matter keys, navigation, and the site hooks."
keywords: ["configuration", "params", "front matter"]
weight: 20
---

The theme consumes only the keys listed here; anything else is ignored. Every
key's default lives in the theme's `config/_default/params.toml` — that file is
both the source of truth and the complete list. Hugo merges it underneath your
site's config, so a site value for any key wins here.

Hugo folds content front matter keys to lowercase (`showBreadcrumbs`
arrives as `showbreadcrumbs`), so page keys below are read lowercase —
write them in any case. Site config keys keep their case.

## Theme defaults (`config/_default/params.toml`)

The file carries every key the theme reads, grouped the way the tables below
are. Override one key in your own `params.toml` and it wins everywhere — in the
templates and in the build scripts, which resolve that same file pair.
Environment overlays (`config/production/`) are honoured by Hugo and by the
build scripts alike; both default to that overlay, and `--environment` names
another.

`[mainSections]` is deliberately absent from it. An empty slice is truthy in Go
templates and `_default/single.html` reads it through `with`, so shipping
`mainSections = []` would flip "every single is an article" into "none is".
Absent means every single is an article.

Two tables stay lowercase — `image` and `build` — because
`scripts/lib/build_config.py` reads the file through `tomllib`, which does not
apply Hugo's case folding.

The image and build thresholds get their own table because the build scripts and
`scripts/place-image.sh` read them as well:

| Key | Default | Effect |
|---|---|---|
| `[params.image].ladder` | `[480, 800, 1280, 1600]` | Variant widths, smallest first. Each is capped by the source width and the role cap, de-duplicated, and dropped if less than 15% wider than its kept predecessor |
| `[params.image].quality` | `78` | One WebP quality for every width, so a width is never stored twice |
| `[params.image].caps.card` | `800` | Widest variant for a card |
| `[params.image].caps.illustration` | `1600` | Widest illustration variant; matches the SciVisual source profile and leaves density headroom at the default reading measure |
| `[params.image].caps.hero` | `1600` | Widest hero variant; deliberately shares the illustration ladder so one source does not create duplicate role-specific transforms. The separate key remains a site override hook |
| `[params.image].og.width` / `.height` | `1200` / `630` | Fixed preview size — what Facebook, LinkedIn and Google request. `scripts/place-image.sh` lints the source against the same pair |
| `[params.build].pageimageskb` | `600` | Largest rendered image payload on one browser visit, in KiB — `check-build` R5; social metadata is excluded because a page visit does not download it |
| `[params.build].minwidth.hero` | `1600` | Minimum source width per role, linted by `scripts/place-image.sh` |
| `[params.build].minwidth.illustration` | `1600` | Same; matches SciVisual's article-illustration output |
| `[params.build].minwidth.card` | `1200` | Same |
| `[params.build].minwidth.og` | `1200` | Same |

`scripts/lib/build_config.py` reads the theme's `config/_default/*.toml` in the
same order Hugo does, then layers your site's config over it — so a threshold
you change in config is the threshold the gate checks.

The production command is `hugo --minify`. `validate-site.sh` audits that exact
artifact and accepts both quoted attributes and Hugo's smaller, unquoted
minifier output. No HTML-minifier override is required.

Disable automatic publication of unused page-bundle originals in the site's
`hugo.toml`:

```toml
[[cascade]]
  [cascade.build]
    publishResources = false
```

Referenced resources and their responsive transforms still publish. This only
prevents an unused source JPEG or PNG from travelling beside its WebP ladder.
`new-site.sh`, the example site and the test fixture carry this setting.

Hugo replaces configuration arrays rather than deep-merging them. If a site
declares `[[cascade]]` again in a higher-priority environment config, that
winning cascade array must include this `publishResources = false` entry too.
Additional cascade rules can be separate blocks in the same winning array.

## Site params (`params.toml`)

| Key | Type / default | Effect |
|---|---|---|
| `colorScheme` | `"default"` | One of the seven shipped names — `default`, `navy`, `forest`, `wine`, `paper`, `clay`, `night`, each light and dark — or your own file under `assets/css/schemes/`. The table is under [Customization](/docs/customization/#colour-schemes). A missing file fails the build and names the scheme. Declare it at the top of the file: a TOML key appended after a `[table]` block such as `[footer.social]` belongs to that table, not to `[params]`, so the theme never sees it and the scheme silently stays `default` with no warning |
| `defaultAppearance` | `"light"` | Initial colour scheme before the stored preference is read: `light`, `dark`, or `auto` to follow the OS until the visitor toggles |
| `autoSwitchAppearance` | `true` | Follow the OS preference until the visitor toggles |
| `logo` | `""` | Asset path to a logo image; rendered in the header. The site title always renders when no logo resolves |
| `disableTextInHeader` | `false` | Hide the site title when (and only when) a logo is present |
| `copyright` | `"© { year } Strata"` | Footer line; `{ year }` is replaced with the current year. Empty or absent falls back to `© {year} {site title}` |
| `description` | `"A Hugo theme for content sites."` | Default `<meta name="description">` (page description/summary wins) |
| `robots` | `"index, follow, max-image-preview:large"` | Default `<meta name="robots">` (page-level `robots` wins). A site setting applies to every page; leave both unset for the default |
| `externalLinksNewTab` | `true` | Content links to another host open in a new tab, so a reference never takes a reader out of the article they are mid-way through, and carry a small arrow so the reader sees the tab stays behind. Internal links and `mailto:` never do — site navigation has to stay in the tab, or every header click would spawn a new one. Scheme-relative `//host` counts as external. Any host other than the site's own counts as external, so links between your own sites open new tabs too |
| `dateFormat` | `"2006-01-02"` | Go time format for card and article dates. Must sit under a `[params]` table — a bare top-level key in `languages.<lang>.toml` is invisible to the theme. For a per-language format, set it in that language's file under its own `[params]` |
| `defaultSocialImage` | — | Asset path used for Open Graph when a page declares no image |
| `eagerCardCount` | `6` | First N cards on a list load their image eagerly |
| `readingMeasure` | `720` | Widest reading column, in pixels — article bodies only. List and landing pages keep the full frame. The column is centred and the text inside stays left-aligned; below it the frame is narrower, so on a phone the body stays flush with the title. A string `"none"` lifts the cap for full-width reading. Shipped as a CSS custom property in `<head>` before the stylesheet, so the column is right on first paint |
| `customCSS` | `[]` | Asset paths loaded after the theme stylesheet (fingerprinted) |
| `rtl` | `false` | Sets `<html dir="rtl">` |
| `allowRemoteImages` | `false` | Permit `https://` image sources; skipped with a warning when off |
| `disableImageOptimization` | `false` | Pass original files through without the WebP ladder |
| `list.cardView` | `true` | Default card vs. row layout for section/term lists |
| `list.showHero` | `false` | Section banner from the section's `featureimage`, above the title; page `showHero` wins, even `false` |
| `list.orderByWeight` | `false` | Sort list pages by `weight` instead of date |
| `list.showSummary` | `false` | Default card summaries on lists |
| `mainSections` | — | Sections whose singles are articles (they get share buttons, related content and previous/next links); other singles render full width and none of them. Compared case-insensitively; absent means every single is an article |
| `header.layout` | `"standard"` | `"smart"` sticks the header and hides it on scroll down, revealing on scroll up |
| `article.showBreadcrumbs` | `false` | Ancestor trail on articles (page `showBreadcrumbs` wins, even `false`) |
| `article.showAuthor` | `false` | `By` line on articles (page `author` wins, then `[author] name`) |
| `article.showDate` | `true` | Date on articles; page `showDate` wins, `false` removes the `<time>` and its separator |
| `article.showDateUpdated` | `true` | `Updated` line when `lastmod` is on a later day than `date`; page `showDateUpdated` wins |
| `article.showSummary` | `true` | A page's `summary` as a standfirst above the meta line. Unlike `list.showSummary`, which is about cards, a page's own summary is written for a reader, so one that is supplied is shown. Page `showsummary: false` suppresses it |
| `article.showToc` | `false` | Table of contents from headings for long articles; page `showtoc` wins |
| `article.showRelatedContent` | `false` | Related-content card grid after the body (see [Related content](#related-content)) |
| `article.relatedContentLimit` | `3` | Maximum related cards; Hugo ranks, the theme only caps |
| `article.showPagination` | `true` | Previous/next links to the neighbouring articles of the same section (see [Previous and next](#previous-and-next)) |
| `article.sharingLinks` | — | Share buttons, names resolved against `data/sharing.json` (see [Share buttons](#share-buttons)) |
| `author.name` | `""` | Site-wide author fallback |
| `author.url` | `""` | The author's own page. Turns the byline into a link and is emitted as the schema `Person.url`; page `authorurl` wins. A URL, not a taxonomy — Hugo reserves the `author` key for authorship, so `author = "authors"` under `[taxonomies]` is ignored and builds no term page |
| `author.links` | `[]` | `[{name, url}]` author profile links, emitted as schema `sameAs` |
| `twitterSite` | `""` | `twitter:site` handle, e.g. `@example` |
| `twitterCreator` | `""` | `twitter:creator` handle; same account as `twitterSite` is fine |
| `ads.client` | `""` | AdSense publisher ID (`ca-pub-…`); enables the `ads` shortcode and requires `static/ads.txt` to name it |
| `ads.auto` | `false` | `true`: loader ships site-wide with no shortcode placed anywhere, and Google's Auto ads choose the pages and the placements (anchor, interstitial, in-page) from the AdSense console. `false` (default): the loader only follows placed units, so nothing loads anywhere it was not placed. Both stack — auto placement and <code>{{&lt; ads &gt;}}</code> units are independent |
| `ads.consent` | — (no default) | Required once `[ads] client` is set and an ad is unlocked; unset fails the build, so a forgot-to-configure site never asks Google silently. `"gated"` keeps the AdSense loader out of `<head>`: the `js/ads.js` copy the shortcode ships reads `localStorage["strata-cookie-consent"]` and the `strata:cookie-consent` event, and injects the loader only once the answer is `granted` — a withdrawal that lands after ads had loaded reloads the current page once, so nothing already running survives the visit. `"none"` ships the loader from `<head>` on unit pages and leaves consent to the site — the mode a Google-certified CMP runs under. The ad CSP check is build-time in both modes, because the loader loads at grant time too. Gated mode also expects the site's `partials/cookie-consent.html` hook (or an explicit `ads.externalConsentController = true`), because a gate with nothing to dispatch the answer keeps every unit hidden forever |
| `ads.externalConsentController` | `false` | Gated-mode escape hatch: your consent controller ships outside the theme's hook (a certified CMP that dispatches `strata:cookie-consent` itself) and the `cookie-consent.html` existence check does not apply |
| `ads.slots.belowHero` | `""` | Numeric ad slot ID placed between header and content; per-page `ads: false` suppresses |
| `ads.slots.belowArticle` | `""` | Numeric ad slot ID placed after article content before sharing links; per-page `ads: false` suppresses |
| `ads.slots.minWords` | `800` | Site-defined minimum article word count for configured slot ads; a density guard, not a substitute for current ad-network policy review |
| `list.showBreadcrumbs` | `false` | Trail on section and home pages |
| `taxonomy.showBreadcrumbs` / `term.showBreadcrumbs` | `false` | Trail on taxonomy overview / term pages |
| `taxonomy.cardView` | `false` | Card vs. row on the taxonomy overview (`/tags/`). False here and true in `[list]`: `/tags/` lists terms, not articles, so it starts as a plain row list |
| `taxonomy.showTermCount` | `true` | Article count beside each term link on the taxonomy overview |
| `term.cardView` / `term.orderByWeight` / `term.showSummary` | `false` | The same three defaults for a taxonomy term page (`/tags/x/`) |

The `taxonomy` and `term` parameter tables only style taxonomy pages; they do
not create them. Site-level `[taxonomies]` controls whether Hugo builds those
pages. Use an empty `[taxonomies]` table when a site intentionally has none.

## Navigation (`menus.en.toml`)

`[[main]]` entries render the header nav (`name`, `pageRef`/`url`,
`weight`). Below 853px the tree collapses behind a hamburger button;
entries with children gain a chevron expander in both modes. Children
attach through `parent` identifiers — inline `[[main.children]]` nesting
is not picked up:

```toml
[[main]]
  name = "Guides"
  identifier = "guides"

[[main]]
  name = "Flat"
  pageRef = "section-a/flat"
  parent = "guides"
```

## Breadcrumbs

Ancestor trail, hidden by default:

```toml
[article]
  showBreadcrumbs = true
```

Only ancestors render — Home, then each parent up to the containing section.
The current page is the `<h1>` beside the trail, so repeating it would be a
crumb with no destination. The JSON-LD `BreadcrumbList` keeps it, since search
engines expect it.

A crumb takes its menu entry's name when the page is in any menu — the same
short label the navigation shows — otherwise the page title. Without this a
section titled "Probiotic Strains and Prebiotic Fiber Ingredients" would ship
that whole string as one crumb. The URL is matched against both the relative
and the baseURL-prefixed form, since Hugo resolves a menu URL to one or the
other depending on how baseURL is set.

Nothing renders when nothing sits above Home: a top-level section or taxonomy
page is already announced by its highlighted menu entry and its own title, and
a trail of just "Home" would be decoration.

Page-level override: `showBreadcrumbs: false` in front matter.

## Structured data

Every rendered page emits one `<script type="application/ld+json">` carrying a
single `@graph`. Nodes reference each other by `@id`, so a crawler walks from a
page to its site, its organisation, its author and its series without guessing:

| Node | When | Fields |
|---|---|---|
| `WebSite` | Home only | `name`, `url`, `inLanguage` |
| `Organization` | Every page | `name` (footer company name, else the site title), `url`, `sameAs` from `[footer] social links`, `logo` |
| `WebPage` | Every page | `name`, `url`, `isPartOf` → `WebSite`, `inLanguage` |
| `BreadcrumbList` | Non-home | `itemListElement` of `ListItem`, position ordered |
| `Article` | Dated pages | `headline`, `mainEntityOfPage` → `WebPage`, `publisher` → `Organization`, `author` → `Person`, `description`, `keywords`, `image`, `datePublished`, `dateModified`, `isPartOfSeries` → `Series` |
| `Series` | A page with a `series` term | `name`, `url`, `hasPart` — each member as an `Article` ref with its `position`, in the same `weight` order as the series navigation |
| `Person` | A byline exists | `name`, `url` when `authorurl` or `[author] url` is set, `sameAs` from `[author] links` |

`datePublished` and `dateModified` always mirror the front matter. A page whose
`lastmod` is earlier than `date` therefore publishes a modified date before its
published date — a contradiction a search engine may treat as fabricated. Hugo
builds that without complaint, so `scripts/validate-content.sh` rejects it in
the source instead of relying on the build to catch it.

## Footer (`params.toml [footer]`)

Without this table the footer is identity, footer menu, copyright. With
it, a grid renders above: company, quick links, legal, contact.

| Key | Type / default | Effect |
|---|---|---|
| `showCompanyInfo` | `true` | Render the grid at all (without the table the footer is identity, menu, copyright) |
| `showAppearanceSwitcher` | `false` | Dark/Light toggle button, rendered at the top right of the header |
| `showScrollToTop` | `false` | Floating round button at the bottom right past 400px scrolled |
| `company.name` / `company.slogan` | — | Brand column; name falls back to the site title |
| `company.email` | — | Entity-obfuscated `mailto:` link |
| `company.phone` | — | `tel:` link, spaces stripped |
| `company.address` | — | Lines split on `<br>`, escaped |
| `quickLinks.title` / `quickLinks.links` | `"Quick Links"` | `[{name, url}]` column |
| `legal.title` / `legal.links` | `"Legal"` | `[{name, url}]` column |
| `social.links` | — | `[{name, icon, url}]` row; icon resolves to `assets/icons/<name>.svg`. The theme ships `linkedin`, `facebook`, `instagram`, `moon`, `sun` as defaults — put a file of the same name in your own `assets/icons/` to override one — and a missing file falls back to the link name |

The footer menu is read from `[[menu.footer]]` in the menus file. An entry
that resolves to no URL — a `pageRef` pointing at a section the site never
declared is the usual cause — is dropped from the output with a build
warning instead of being rendered as a dead link.

## Front matter

| Key | Effect |
|---|---|
| `title` | Required |
| `date` | Card and article date; articles without a date show no `<time>` and no `Article` node |
| `weight` | Ordering when `orderByWeight` is on; series order |
| `description` | Page meta description; also feeds `Article.description`. Wins over `summary` for every machine-readable field |
| `summary` | Fallback meta description when `description` is absent, and the only source of the visible standfirst rendered above the meta line (see `article.showSummary`). Kept as a separate resolver from `description`, so a page can set both with different wording — one for a snippet, one for a reader |
| `keywords` | `["Prebiotic", "Bifidobacterium"]` — feeds both `<meta name="keywords">` and `Article.keywords` from one resolver; falls back to `tags`, which may be a list or a bare comma string. Items are trimmed, deduplicated and blank-dropped, and with no source at all no tag is emitted |
| `url` | `"/solutions/infant-nutrition/"` — Hugo serves the page here and `canonical`/Open Graph follow it. It creates no redirect, so the path the file would otherwise have returns 404 |
| `tags` | `["alpha", "beta"]` — rendered as tag links via `GetTerms` |
| `series` | `["series-a"]` — first entry drives series navigation via `GetTerms` |
| `featureimage` | Page/card image under `assets/images/`; a legacy bundle resource named `feature*`/`cover*`/`thumbnail*` remains a migration fallback (see [images.md](/docs/images/)) |
| `featureimagealt` | Alt text for `featureimage`; fallback `Featured image for {title}` |
| `showHero` | Page hero: shown when an image resolves (`featureimage` or a legacy bundle cover), `false` suppresses it |
| `showAuthor` | Page-level `By` line override (falls back to `[article] showAuthor`) |
| `showDate` | Page-level date override (falls back to `[article] showDate`, explicit `false` wins) |
| `showDateUpdated` | Page-level `Updated` override (falls back to `[article] showDateUpdated`) |
| `lastmod` | Update day. `dateModified` and `article:modified_time` always reflect it; the visible `Updated` line is only gated by `showDateUpdated`, so hiding that line never hides the machine-readable signal. Only front matter counts — file mtime is never used, so an unrelated save cannot move the update date |
| `showRelatedContent` | Page-level related-content override (falls back to `[article] showRelatedContent`) |
| `showPagination` | Page-level previous/next override (falls back to `[article] showPagination`) |
| `showBreadcrumbs` | Page-level trail override (falls back to the Kind table, explicit `false` wins) |
| `showToc` | Page-level Table of Contents override (falls back to `[article] showToc`) |
| `reviewer` | Peer reviewer or fact-checker name for E-E-A-T (e.g. `Dr. Jane Doe`). Rendered in article byline as `Reviewed by...` and emitted in JSON-LD as `reviewedBy` |
| `reviewerURL` | Optional profile link for the reviewer |
| `reviewerJobTitle` | Professional academic or research title for reviewer in JSON-LD |
| `reviewerAffiliation` | Institutional affiliation for reviewer (emitted as `worksFor` in JSON-LD) |
| `reviewerSameAs` | List of authoritative external profile URLs (ORCID, Google Scholar, Wikipedia) for reviewer |
| `ads` | `false` suppresses all auto-injected ad slots on this article |
| `robots` | Page-level robots meta |
| `cardView` / `showSummary` / `orderByWeight` | Per-page override of the list/term defaults above |
| `draft` | Standard Hugo draft flag |
| `author` | Byline for this page (falls back to `[author] name`). Emits the schema `Person.name` |
| `authorurl` | `"/about/"` — turns the byline into a link and emits the schema `Person.url`. Page-level; falls back to `[author] url`. Set neither and the byline is plain text |
| `images` | Image refs for Open Graph; `images[0]` is used only when `featureimage` is absent (see [images.md](/docs/images/)) |

A production article can start from this compact front matter. Fill every empty
value before changing `draft` to `false`; the content lint enforces the fields
that feed search and structured data.

### The overrides above, demonstrated

Page-level overrides are demonstrated live on this site, not only described
here, so you can inspect the page and the front matter together:

| Page | Override | Why it is there |
|---|---|---|
| [Documentation](/docs/) | `showSummary: false` | A docs index needs neither standfirsts nor card summaries |
| [Shipping images that load](/posts/shipping-images-that-load/) | `author`, `authorurl` | A contributor post, whose byline and schema `Person.url` both differ from the site's `[author]` table |

Not every override has a page that wants it, and forcing one would mean writing
content about the feature rather than the product. `scripts/validate-example.sh`
reports the undemonstrated keys as a warning rather than a failure, so the list
stays visible when a new one arrives.



```yaml
---
title: ""
description: ""
summary: ""
keywords: []
author: ""
date: 2026-01-01
lastmod: 2026-01-01
draft: true
tags: []
featureimage: ""
featureimagealt: ""
showHero: true
showSummary: true
weight: 0
---
```

`description` is the search snippet; `summary` is the reader-facing standfirst
and its metadata fallback. Update `lastmod` only for a substantive revision.
`layout` is intentionally absent: Strata has one single-page template, so a
front matter `layout` value is accepted for Hugo compatibility but has no theme
effect.

## Consent and ads

The theme ships no consent UI. Its AdSense loader is dormant unless the site
provides `[ads] client` **and** either a page uses the `ads` shortcode or the
site opts into `[ads] auto`; sites wire
consent and ads through two sanctioned points:

- `partials/cookie-consent.html` (hook above) renders site-owned banner or
  CMP markup before `</body>`. Load Consent Mode defaults before any
  measurement tag — typically from `partials/extend-head.html` — and flip
  to granted from the banner. What counts as consent is site law, not
  theme code.
- <code>{{&lt; ads slot="…" &gt;}}</code> renders an AdSense unit; `static/ads.txt` must
  name the `[ads] client` ID as a real record or the build fails (check-build
  R11), and the `/privacy-policy/` and `/cookies/` pages must ship complete —
  no `[TBD]` in the published copy — or check-build R17 fails the build.

### Who places the ads

Placement is the one lever with two owners, and choosing wrong shows up in
the reader's scroll:

- **Manual (default): you place, Google serves.** <code>{{&lt; ads slot="…" &gt;}}</code>
  in the content is the whole contract — the ad renders where you landed
  it, and no ad exists on any page that never used the shortcode. This is
  the mode for sites that own the reading experience: a science section,
  docs, anything where a mid-paragraph ad is a defect.

- **Optional: `[ads] auto = true`, Google places too.** The loader ships
  site-wide and the AdSense console drives what happens next, grouped by
  behaviour: *overlay* formats (anchor — sticky top/bottom, dismissible;
  vignette — full-screen between page loads, skippable, with a frequency
  setting; side rail) never displace page content, while *in-page* formats
  (banner, Multiplex) land inside the page's own areas — which is where
  "乱放多放" lives, because the algorithm, not the page author, picks the
  spots. The console's levers (Auto ads → Edit → ad settings) are real but
  live in Google, not in Hugo: per-format switches, a maximum-ads slider
  and a minimum-distance slider for banner ads, vignette frequency,
  excluded pages and excluded areas, plus an ad-settings preview that can
  strip an auto placement it dislikes. Ads where manual units exist don't
  collide — Google optimizes around existing units unless you let it
  ("Allow Google to optimize existing ads").

The honest summary: `auto` trades control for coverage. A practical
compromise keeps the copy untouched — `auto = true` with both in-page
formats (banner, Multiplex) unchecked, overlay kept at will — and honed
with the console's 50%-traffic experiments before going site-wide.
The theme ships no opinions past the switch: everything after it is
account-side and unverifiable from a build.

### The consent answer as a contract

`[ads] consent` has no default: a site that forgets to pick fails the build,
never ships an ad request it did not choose. Two values, both explicit:

- `"none"`:  the site answers for itself — the loader ships from
  `<head>` on unit pages. This is the shape a site runs behind a
  Google-certified CMP, which is the only self-service path for
  personalized advertising to EEA/UK/Switzerland traffic anyway.
- `"gated"`: the loader waits for the site's answer. `js/ads.js` — the
  fingerprinted push copy every unit ships — reads
  `localStorage["strata-cookie-consent"]` for `granted`/`denied` and
  listens for the `CustomEvent("strata:cookie-consent")` with the same
  detail; a granted answer injects the loader once, drains the units in DOM
  order, and lifts the `data-ads-pending` visibility until then. Write the
  two values from your own banner controller, exactly as the fixture does
  (`test/fixture/assets/js/consent.js` beside
  `layouts/partials/cookie-consent.html`): ask once, persist once, dispatch
  once, keep the reopen control on the page. Gated mode is not a CMP and
  does not pretend to be one: no category granularity, no IAB TCF string,
  no cross-domain anything — a site that needs those runs `"none"` behind
  a certified CMP instead. One edge: in gated mode the dispatcher rides
  the unit copies the shortcode ships, so `auto` with no placed unit is
  rejected at build time — place one unit for the carrier, or run
  `"none"` under a certified CMP. Two closing pins: gated also refuses a
  site that ships no `partials/cookie-consent.html` hook (nothing would
  ever dispatch the answer) unless `ads.externalConsentController = true`
  declares the controller lives in your own code; and a withdrawal that
  lands after ads have loaded reloads the current page once, because a
  half-disarmed in-document ad runtime is not a withdrawal.

Waiting for the answer does not lift the origin policy: `gated` mode still
requires `static/_headers` to allow `pagead2.googlesyndication.com`, and
head.html checks that at build time — the loader loads once the answer is
granted, into the same policy.

### The pages a banner points at

A banner that says "we use cookies" and points nowhere is not a notice.
Three pages make it one, and this example publishes all three as
templates with every `[TBD]` left for the reader to fill:

| Page | Says | Template |
|---|---|---|
| [Privacy policy](/privacy-policy/) | who collects, what, why, for how long, your rights | `content/privacy-policy.md` |
| [Cookies](/cookies/) | the short list the banner links from | `content/cookies.md` |
| [Terms of use](/terms/) | how the site may be used, and our limits | `content/terms.md` |

`scripts/new-site.sh` creates the same three as stub pages with TODO
comments, so a new site starts with the right shape and nothing invented.

A `[TBD]` is a fact about your site, not a writing exercise. Three of
them are not optional: whether consent law applies here and on what
basis, a link to [Google Ad Settings](https://adssettings.google.com) for
anyone who wants to turn ad personalization off, and a cookie table that
names only cookies the site actually sets — deleting a row means the
vendor is gone, not just gone from the table.

## Site hooks

Drop-in partials a site may provide; the theme calls them when present:

| Partial | Called from | Purpose |
|---|---|---|
| `partials/extend-head.html` | `head/head.html` | Extra head markup (cached) |
| `partials/extend-head-uncached.html` | `head/head.html` | Extra head markup (uncached) |
| `partials/extend-article-link.html` | `page/card.html` | Extra markup at the end of each card, after the summary. Not inside the link, despite the name |
| `partials/cookie-consent.html` | `_default/baseof.html` | Site-owned consent banner/CMP (see Consent below) |

Every one of these is implemented in this example's own `layouts/partials/`,
which is the reference to copy from: `exampleSite/layouts/partials/`.

## Favicons

The theme ships a small default set: SVG and ICO browser icons, a 180px Apple
Touch icon, 192px and 512px PWA icons, and a monochrome Safari pinned-tab
mask. A site can replace any file by putting the same name under `static/`.
For different markup, override `layouts/partials/favicons.html`; the default
partial links `site.webmanifest` only when that file exists in the site.

## Render hooks

Markdown renderers Goldmark calls, in `layouts/_default/_markup/`. A site
overrides one by placing a file at the same path in its own layouts. Neither is
optional the way the site hooks above are: the theme always provides both, so
copying one replaces it rather than adding to it. See [Customization](/docs/customization/#render-hooks)
for the details and the override examples.

| Template | Called for | Purpose |
|---|---|---|
| `_default/_markup/render-link.html` | Every link in markdown content | External links open in a new tab, carry a marker, and gain `class="link--external"` as a styling hook; gated by `externalLinksNewTab` |
| `_default/_markup/render-image.html` | Every `![](x)` in markdown content | Joins the responsive pipeline instead of falling through to Goldmark's plain `<img>` |


## Unsupported keys

These keys are accepted by Hugo or older Strata versions but have **no
effect** in the current theme. They are listed so nobody configures them by
accident:

- page front matter `compactSummary` — silently ignored by every
  template; the fixture smoke gate fails on it so it never sneaks back in
- page front matter `layout` — a Jekyll leftover (e.g.
  `layout: "single"`); Strata has one single layout, so the value is never read
- page front matter or site `heroStyle` — Strata renders one hero at every
  level, so the value is never read
- page front matter `series_order` — series navigation sorts by `weight`; set
  only `weight` and drop `series_order`
- site `[article]` / `[term]` `showHero`, and `[taxonomy] showHero` /
  `orderByWeight` / `showSummary` — read by nothing: an article renders its body
  rather than cards, `/tags/` and `/tags/x/` list terms rather than pages, and
  Strata shows a hero whenever an image resolves. Only `[list] showHero` is
  read, for a section banner. `showSummary` is read under `[list]` and `[article]`
  only — card summaries and the article standfirst
- site `showDraftLabel` — Strata has no draft badge
- `[params] backgroundImageWidth` — superseded by the pipeline's own widths

## Search (`enableSearch`)

Two keys opt in, both required:

```toml
enableSearch = true

[outputs]
  home = ["HTML", "RSS", "JSON"]
```
`layouts/home.json` emits the index: article pages only (the
`mainSections` rule from `single.html`), each with `title`, `url`,
`date`, `summary` and the first `search.contentLength` characters of
plain text (2000 by default) — no image
fields, result items are text-only. `assets/js/search.js` fetches it on
first open and scores in-page: every query token must occur somewhere,
title hits weigh 3, summary 2, body 1, top ten render. The header button
opens a dropdown panel (the disclosure contract from the mobile menu:
`aria-expanded` sync, Escape closes with focus back, the panels close
each other). A search button with no `index.json` fails check-build.

## Accessibility panel (`enableA11y`)

`enableA11y = true` renders a third header dropdown with three switches.
Choices persist in `localStorage` and apply as classes on `<html>`, so
they hold across navigation. `assets/js/a11y.js` loads in `<head>`, before
the first paint, so a stored preference never flashes the other way.

| Switch | Class | Effect |
|---|---|---|
| Underline links | `a11y-underline-links` | Every `a` gets a 2px underline |
| Reduce motion | `a11y-reduce-motion` | Kills animations and transitions; the carousel stops autoplaying and scroll-to-top becomes instant — both re-read the class, so it takes effect without a reload |
| Strong focus | `a11y-strong-focus` | Focus outline goes from 2px to 4px |

When the visitor's OS already prefers reduced motion, *Reduce motion* is
disabled and labelled as such. Both rules only ever turn motion off, so
the switch could never re-enable it — a live checkbox there would look
like it did something when it cannot.

No font-size switch on purpose: the theme mixes `rem` (headings) with `px`
(prose and components), so a root bump scales only half the type and leaves
it inconsistent. Browser zoom scales everything uniformly, which is what
WCAG 1.4.4 asks for and what `docs/typography.md` already recommends. No
background-image switch either — this theme has no background heroes to
turn off. `scripts/smoke.sh` asserts the omission is documented, so adding
one later means updating the gate too.

The three header dropdowns share one contract in `assets/js/dropdowns.js`:
at most one is open, `aria-expanded` stays in sync, Escape closes with
focus back on its own button. A new dropdown is one
`strataRegisterDropdown` call.

## Related content

Two things are required, and they are independent — Hugo ranks, the theme
only asks for the result:

```toml
# params.toml
[article]
  showRelatedContent = true
  relatedContentLimit = 3

# hugo.toml — what "related" means and the score floor
[related]
  threshold = 80
  toLower = false
  includeNewer = true

  [[related.indices]]
    name = "tags"
    weight = 100

  [[related.indices]]
    name = "series"
    weight = 50
```

`threshold` is a 0–100 score floor. `weight` is relative, so `tags` at 100
and `series` at 50 means a shared tag counts double a shared series. `weight`
is also the ceiling of the normalized score, so a term that only shares a
low-weight index rarely clears the floor — a shared `series` at 50 alone
normalizes to 0 and never matches at `threshold = 80`, while a shared `tags`
at 100 normalizes to 100.

**`includeNewer` matters.** Hugo excludes newer pages by default, with the
comment *"To get stable 'See also' sections we, by default, exclude newer
related pages"*. That makes the block directional: a recent article lists
older ones, and the oldest article in a tag has nothing to point at, so its
Related block is simply absent. With `includeNewer = true` the pair is
bidirectional and every article with a common term gets a block. For a
journal or a reference site set it to `true`; for a chronological news log
Hugo's default is arguably right.

A page with no terms in common with anything renders no block at all — an
empty result is not an error and leaves no dead heading behind. Hugo computes
the list lazily per page.

The block is a card grid, three columns wide and capped at
`relatedContentLimit` cards. Every card loads its image lazily and deprioritised
— the block sits below a long article, so no entry may cost the first paint.

Page-level override: `showRelatedContent: false` in front matter.

## Previous and next

```toml
[article]
  showPagination = true
```

On by default. Each article links to its neighbours inside the same section —
the older one on the left, the newer one on the right — from Hugo's
`PrevInSection` and `NextInSection`, which sort by date. A lone article prints
nothing rather than an empty bar.

Page-level override: `showPagination: false` in front matter.

## Share buttons

```toml
[article]
  sharingLinks = ["linkedin", "facebook", "email", "whatsapp"]
```

Each name resolves against `data/sharing.json`. The theme ships the four
above; a site's own `data/sharing.json` **merges over it** — every key the
site names is replaced, every key it omits is inherited, and a new name
adds a button. No template change is needed to add a service.

```json
{
  "mastodon": {
    "label": "Mastodon",
    "url": "https://mastodon.social/share?text=%[2]s+%[1]s"
  }
}
```

Two arguments are passed to `printf`, in this order: the permalink, then
the title (already run through `urlquery`, so spaces and `&` survive the URL).
Include both slots in every template, or use `%[1]s` / `%[2]s` to reorder
without renaming. `scripts/validate-theme.sh` fails the build unless every
`url` in the theme's own `data/sharing.json` has exactly two verbs.

Separate the two with a literal `+`, the way the default WhatsApp entry does
it. Do not write `%20`: `printf` scans the format string for verbs and reads
`%2` as an unknown one, emitting `%!2(MISSING)` into the URL. Leaving one
slot unused is the other half of the same trap — an extra argument appends a
`%!N(EXTRA …)` marker to the URL and the link stops working.

Every entry may set `"blank": false`. All four defaults render with
`target="_blank" rel="noopener noreferrer"` except `email`, which sets it
`false` — a `mailto:` URL does not open a tab, and some browsers show a
blank one first.

`label` falls back to the name if omitted. A name that resolves to nothing
in `data/sharing.json` renders no button rather than a dead one. Links are
plain anchors with `target="_blank" rel="noopener noreferrer"` — no share
widget, no third-party script.

Each tile is a 44×44 icon when `assets/icons/<name>.svg` exists and falls back
to the `label` text otherwise, so a service added to a site's `data/sharing.json`
stays reachable without a template change. The `label` doubles as the
`aria-label`, since the icon is decorative. A site's own
`assets/icons/<name>.svg` overrides a same-named theme icon.

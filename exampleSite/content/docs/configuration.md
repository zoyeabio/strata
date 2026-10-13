---
title: "Configuration"
description: "Site params, front matter keys, navigation, and the site hooks."
keywords: ["configuration", "params", "front matter"]
weight: 20
---

Everything a site configures lives in the site layer. The theme consumes only
the keys listed here; anything else is ignored. The theme's own defaults —
the image pipeline and the build thresholds — live in the theme's root
`config.toml` and are listed in [Theme defaults](#theme-defaults-configtoml).

Hugo folds content front matter keys to lowercase (`showBreadcrumbs`
arrives as `showbreadcrumbs`), so page keys below are read lowercase —
write them in any case. Site config keys keep their case.

## Theme defaults (`config.toml`)

The theme loads `config.toml` first, so these values merge underneath your
site's config: override a single key in your own `params.toml` and it wins
everywhere, in the templates and in the build scripts, which resolve the same
file pair. Hugo also merges a theme's `config/_default/`, but these defaults
are not kept there as well — a theme ships them from one place only.
Environment overlays (`config/production/`) are honoured by Hugo and by the
build scripts alike; both default to that overlay, and `--environment` names
another.

| Key | Default | Effect |
|---|---|---|
| `[params.image].ladder` | `[480, 800, 1280, 1920]` | Variant widths, smallest first. Each is capped by the source width and the role cap, de-duplicated, and dropped if less than 15% wider than its kept predecessor |
| `[params.image].quality` | `78` | One WebP quality for every width, so a width is never stored twice |
| `[params.image].caps.card` | `800` | Widest variant for a card |
| `[params.image].caps.illustration` | `1280` | Widest variant for an illustration |
| `[params.image].caps.hero` | `1920` | Widest variant for a hero |
| `[params.image].caps.og` | `1920` | Widest variant for the social preview |
| `[params.image].og.width` / `.height` | `1200` / `630` | Fixed preview size — what Facebook, LinkedIn and Google request. `scripts/place-image.sh` lints the source against the same pair |
| `[params.build].pageimageskb` | `600` | Largest total image payload on a page, in KiB — `check-build` R5 |
| `[params.build].minwidth.hero` | `1600` | Minimum source width per role, linted by `scripts/place-image.sh` |
| `[params.build].minwidth.illustration` | `1280` | Same |
| `[params.build].minwidth.card` | `1200` | Same |
| `[params.build].minwidth.og` | `1200` | Same |

`scripts/lib/build_config.py` resolves that same file pair for the build
scripts, so a threshold you change in config is the threshold the gate checks.

## Site params (`params.toml`)

| Key | Type / default | Effect |
|---|---|---|
| `colorScheme` | `"strata-default"` | Colour scheme file name under `assets/css/schemes/`. A missing file fails the build and names the scheme |
| `defaultAppearance` | `"light"` | Initial colour scheme before the stored preference is read (`light` or `dark`) |
| `autoSwitchAppearance` | `true` | Follow the OS preference until the visitor toggles |
| `logo` | — | Asset path to a logo image; rendered in the header. The site title always renders when no logo resolves |
| `disableTextInHeader` | `false` | Hide the site title when (and only when) a logo is present |
| `copyright` | — | Footer line; `{ year }` is replaced with the current year. Fallback: `© {year} {site title}` |
| `description` | — | Default `<meta name="description">` (page description/summary wins) |
| `robots` | `"index, follow, max-image-preview:large"` | Default `<meta name="robots">` (page-level `robots` wins). A site setting applies to every page; leave both unset for the default |
| `dateFormat` | `"2006-01-02"` | Go time format for card and article dates. Declare it under a `[params]` table (the theme's `languages.en.toml` does this); a bare top-level key in `languages.<lang>.toml` is invisible to the theme |
| `defaultSocialImage` | — | Asset path used for Open Graph when a page declares no image |
| `eagerCardCount` | `6` | First N cards on a list load their image eagerly |
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
| `article.showRelatedContent` | `false` | Related-content card grid after the body (see [Related content](#related-content)) |
| `article.relatedContentLimit` | `3` | Maximum related cards; Hugo ranks, the theme only caps |
| `article.showPagination` | `true` | Previous/next links to the neighbouring articles of the same section (see [Previous and next](#previous-and-next)) |
| `article.sharingLinks` | — | Share buttons, names resolved against `data/sharing.json` (see [Share buttons](#share-buttons)) |
| `author.name` | — | Site-wide author fallback |
| `author.links` | — | `[{name, url}]` author profile links, emitted as schema `sameAs` |
| `twitterSite` | — | `twitter:site` handle, e.g. `@example` |
| `twitterCreator` | — | `twitter:creator` handle; same account as `twitterSite` is fine |
| `ads.client` | — | AdSense publisher ID (`ca-pub-…`); enables the `ads` shortcode and requires `static/ads.txt` to name it |
| `list.showBreadcrumbs` | `false` | Trail on section and home pages |
| `taxonomy.showBreadcrumbs` / `term.showBreadcrumbs` | `false` | Trail on taxonomy overview / term pages |
| `term.cardView` / `term.orderByWeight` / `term.showSummary` | — | Same three defaults for taxonomy term pages |
| `taxonomy.cardView` | — | Card vs. row on the taxonomy overview (`/tags/`) |

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
| `description` / `summary` | Page meta description; both also feed `Article.description` (description wins) |
| `keywords` | `["Prebiotic", "Bifidobacterium"]` — feeds both `<meta name="keywords">` and `Article.keywords` from one resolver; falls back to `tags`, which may be a list or a bare comma string. Items are trimmed, deduplicated and blank-dropped, and with no source at all no tag is emitted |
| `url` | `"/solutions/infant-nutrition/"` — Hugo serves the page here and `canonical`/Open Graph follow it. It creates no redirect, so the path the file would otherwise have returns 404 |
| `tags` | `["alpha", "beta"]` — rendered as tag links via `GetTerms` |
| `series` | `["series-a"]` — first entry drives series navigation via `GetTerms` |
| `featureimage` | Page/card image; without it a bundle resource named `feature*`/`cover*`/`thumbnail*` is used (see [images.md](/docs/images/)) |
| `featureimagealt` | Alt text for `featureimage`; fallback `Featured image for {title}` |
| `showHero` | Page hero: shown when an image resolves (`featureimage` or a bundle cover), `false` suppresses it |
| `showAuthor` | Page-level `By` line override (falls back to `[article] showAuthor`) |
| `showDate` | Page-level date override (falls back to `[article] showDate`, explicit `false` wins) |
| `showDateUpdated` | Page-level `Updated` override (falls back to `[article] showDateUpdated`) |
| `lastmod` | Update day. `dateModified` and `article:modified_time` always reflect it; the visible `Updated` line is only gated by `showDateUpdated`, so hiding that line never hides the machine-readable signal. Only front matter counts — file mtime is never used, so an unrelated save cannot move the update date |
| `showRelatedContent` | Page-level related-content override (falls back to `[article] showRelatedContent`) |
| `showPagination` | Page-level previous/next override (falls back to `[article] showPagination`) |
| `showBreadcrumbs` | Page-level trail override (falls back to the Kind table, explicit `false` wins) |
| `robots` | Page-level robots meta |
| `cardView` / `showSummary` / `orderByWeight` | Per-page override of the list/term defaults above |
| `draft` | Standard Hugo draft flag |
| `author` | Byline for this page (falls back to `[author] name`) |
| `images` | Image refs for Open Graph; `images[0]` is used only when `featureimage` is absent (see [images.md](/docs/images/)) |

## Consent and ads

The theme ships no consent UI and no ad loader of its own. Sites wire
theirs through two sanctioned points:

- `partials/cookie-consent.html` (hook above) renders site-owned banner or
  CMP markup before `</body>`. Load Consent Mode defaults before any
  measurement tag — typically from `partials/extend-head.html` — and flip
  to granted from the banner. What counts as consent is site law, not
  theme code.
- <code>{{&lt; ads slot="…" &gt;}}</code> renders an AdSense unit; `static/ads.txt` must
  name the `[ads] client` ID or the build fails (check-build R11).

## Site hooks

Drop-in partials a site may provide; the theme calls them when present:

| Partial | Called from | Purpose |
|---|---|---|
| `partials/favicons.html` | `head/head.html` | Site favicon links |
| `partials/extend-head.html` | `head/head.html` | Extra head markup (cached) |
| `partials/extend-head-uncached.html` | `head/head.html` | Extra head markup (uncached) |
| `partials/extend-article-link.html` | `page/card.html` | Extra markup inside each card link |
| `partials/cookie-consent.html` | `_default/baseof.html` | Site-owned consent banner/CMP (see Consent below) |

## Unsupported keys

These keys are accepted by Hugo or older Strata versions but have **no
effect** in the current theme. They are listed so nobody configures them by
accident:

- page front matter `compactSummary` — silently ignored by every
  template; the fixture smoke gate fails on it so it never sneaks back in
- page front matter `layout` — a Jekyll/zoyclaw leftover (e.g.
  `layout: "single"`); Strata has one single layout, so the value is never read
- page front matter or site `heroStyle` — Strata renders one hero at every
  level. zoyclaw only honoured it when a `partials/hero/<style>.html` file
  existed, so `"basic"` was already a silent no-op there
- page front matter `series_order` — series navigation sorts by `weight`; set
  only `weight` and drop `series_order`
- site `[article]` / `[list]` / `[taxonomy]` / `[term]` `showHero` — only the
  page front matter `showHero` is read; a site `true` is a no-op because
  Strata shows a hero whenever an image resolves
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

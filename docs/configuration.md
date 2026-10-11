# Configuration

All configuration lives in the site layer. The theme consumes only the keys
listed here; anything else is ignored.

Hugo folds content front matter keys to lowercase (`showBreadcrumbs`
arrives as `showbreadcrumbs`), so page keys below are read lowercase —
write them in any case. Site config keys keep their case.

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
| `robots` | — | Default `<meta name="robots">` (page-level `robots` wins) |
| `dateFormat` | `"2006-01-02"` | Go time format for card and article dates |
| `defaultSocialImage` | — | Asset path used for Open Graph when a page declares no image |
| `eagerCardCount` | `6` | First N cards on a list load their image eagerly |
| `customCSS` | `[]` | Asset paths loaded after the theme stylesheet (fingerprinted) |
| `rtl` | `false` | Sets `<html dir="rtl">` |
| `allowRemoteImages` | `false` | Permit `https://` image sources; skipped with a warning when off |
| `disableImageOptimization` | `false` | Pass original files through without the WebP ladder |
| `list.cardView` | `true` | Default card vs. row layout for section/term lists |
| `list.orderByWeight` | `false` | Sort list pages by `weight` instead of date |
| `list.showSummary` | `false` | Default card summaries on lists |
| `mainSections` | — | Sections whose singles are articles (prose-capped); other singles render full width. Compared case-insensitively; absent means every single is an article |
| `header.layout` | `"standard"` | `"smart"` sticks the header and hides it on scroll down, revealing on scroll up |
| `article.showBreadcrumbs` | `false` | Ancestor trail on articles (page `showBreadcrumbs` wins, even `false`) |
| `article.showAuthor` | `false` | `By` line on articles (page `author` wins, then `[author] name`) |
| `article.showDate` | `true` | Date on articles; page `showDate` wins, `false` removes the `<time>` and its separator |
| `article.showRelatedContent` | `false` | Related-content card grid after the body (see [Related content](#related-content)) |
| `article.relatedContentLimit` | `3` | Maximum related cards; Hugo ranks, the theme only caps |
| `article.showSummary` | `false` | Card summaries in the related grid |
| `article.sharingLinks` | — | Share buttons, names resolved against `data/sharing.json` (see [Share buttons](#share-buttons)) |
| `author.name` | — | Site-wide author fallback |
| `author.links` | — | `[{name, url}]` author profile links, emitted as schema `sameAs` |
| `twitterSite` | — | `twitter:site` handle, e.g. `@example` |
| `ads.client` | — | AdSense publisher ID (`ca-pub-…`); enables the `ads` shortcode and requires `static/ads.txt` to name it |
| `list.showBreadcrumbs` | `false` | Trail on section and home pages |
| `taxonomy.showBreadcrumbs` / `term.showBreadcrumbs` | `false` | Trail on taxonomy overview / term pages |
| `term.cardView` / `term.orderByWeight` / `term.showSummary` | — | Same three defaults for taxonomy term pages |
| `taxonomy.cardView` | — | Card vs. row on the taxonomy overview (`/tags/`) |
| `schema.enableProduct` | `false` | Reserved for product JSON-LD (site-layer product template, planned) |

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
| `social.links` | — | `[{name, icon, url}]` row; icon resolves to `assets/icons/<name>.svg`, a missing file falls back to the link name |

## Front matter

| Key | Effect |
|---|---|
| `title` | Required |
| `date` | Card and article date; articles without a date show no `<time>` |
| `weight` | Ordering when `orderByWeight` is on; series order |
| `description` / `summary` | Page meta description; summary also feeds `.Summary` |
| `tags` | `["alpha", "beta"]` — rendered as tag links via `GetTerms` |
| `series` | `["series-a"]` — first entry drives series navigation via `GetTerms` |
| `featureimage` | Page/card image (see [images.md](images.md)) |
| `featureimagealt` | Alt text for `featureimage`; fallback `Featured image for {title}` |
| `showHero` | Page hero: shown when `featureimage` resolves, `false` suppresses it |
| `showAuthor` | Page-level `By` line override (falls back to `[article] showAuthor`) |
| `showDate` | Page-level date override (falls back to `[article] showDate`, explicit `false` wins) |
| `showRelatedContent` | Page-level related-content override (falls back to `[article] showRelatedContent`) |
| `showBreadcrumbs` | Page-level trail override (falls back to the Kind table, explicit `false` wins) |
| `robots` | Page-level robots meta |
| `cardView` / `showSummary` / `orderByWeight` | Per-page override of the list/term defaults above |
| `draft` | Standard Hugo draft flag |
| `author` | Byline for this page (falls back to `[author] name`) |
| `images` | Image refs for Open Graph (first entry wins, before `featureimage`) |

## Consent and ads

The theme ships no consent UI and no ad loader of its own. Sites wire
theirs through two sanctioned points:

- `partials/cookie-consent.html` (hook above) renders site-owned banner or
  CMP markup before `</body>`. Load Consent Mode defaults before any
  measurement tag — typically from `partials/extend-head.html` — and flip
  to granted from the banner. What counts as consent is site law, not
  theme code.
- `{{< ads slot="…" >}}` renders an AdSense unit; `static/ads.txt` must
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
- `backgroundImageWidth` — superseded by the pipeline's own widths

## Not implemented (planned)

Table of contents, syntax highlighting CSS, i18n string catalogue,
product pages. See the project roadmap.

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

  [[related.indices]]
    name = "tags"
    weight = 100

  [[related.indices]]
    name = "series"
    weight = 50
```

`threshold` is a 0–100 score floor. `weight` is relative, so `tags` at 100
and `series` at 50 means a shared tag counts double a shared series. A page
with no terms in common with anything renders no block at all — an empty
result is not an error and leaves no dead heading behind. Related scoring
is symmetric, so if `B` appears under `A` then `A` appears under `B`; Hugo
computes the list lazily per page.

The cards come from `page/page-collection.html`, the same grid as the list
pages, so `article.showSummary` controls their summaries. Page-level
override: `showRelatedContent: false` in front matter.

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
    "url": "https://mastodon.social/share?text=%[2]s%20%[1]s"
  }
}
```

Two arguments are passed to `printf`, in this order: the permalink, then
the title (already run through `urlquery`, so spaces and `&` survive the URL).
Include both slots in every template, or use `%[1]s` / `%[2]s` to reorder
without renaming. Separating them with a literal `+` is how the default
WhatsApp entry does it — writing `%20` instead breaks, because `printf`
reads `%2` as an unknown verb and emits `%!2(MISSING)`. Leaving one slot
unused appends a `%!N(EXTRA …)` marker to the URL and the link stops
working.

`label` falls back to the name if omitted. A name that resolves to nothing
in `data/sharing.json` renders no button rather than a dead one. Links are
plain anchors with `target="_blank" rel="noopener noreferrer"` — no icon
font, no share widget, no third-party script.

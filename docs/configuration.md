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
| `article.showBreadcrumbs` | `false` | Ancestor trail on articles (page `showBreadcrumbs` wins, even `false`) |
| `article.showAuthor` | `false` | `By` line on articles (page `author` wins, then `[author] name`) |
| `author.name` | — | Site-wide author fallback |
| `author.links` | — | `[{name, url}]` author profile links, emitted as schema `sameAs` |
| `twitterSite` | — | `twitter:site` handle, e.g. `@example` |
| `ads.client` | — | AdSense publisher ID (`ca-pub-…`); enables the `ads` shortcode and requires `static/ads.txt` to name it |
| `list.showBreadcrumbs` | `false` | Trail on section and home pages |
| `taxonomy.showBreadcrumbs` / `term.showBreadcrumbs` | `false` | Trail on taxonomy overview / term pages |
| `term.cardView` / `term.orderByWeight` / `term.showSummary` | — | Same three defaults for taxonomy term pages |
| `taxonomy.cardView` | — | Card vs. row on the taxonomy overview (`/tags/`) |
| `schema.enableProduct` | `false` | Reserved for product JSON-LD (site-layer product template, planned) |

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
- `enableSearch` — search is not built yet
- `backgroundImageWidth` — superseded by the pipeline's own widths

## Not implemented (planned)

Search (`index.json`), related-content block, table of contents, syntax
highlighting CSS, i18n string catalogue, product pages. See the project
roadmap.

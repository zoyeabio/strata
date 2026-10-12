# Shortcodes

All shortcodes ship with the theme; no JavaScript dependencies are bundled.
Parameters marked **required** fail the build when missing (with the source
position in the error).

## figure

Responsive version of Hugo's built-in `figure`. Same parameter surface,
image runs through the responsive pipeline.

| Parameter | Notes |
|---|---|
| `src` | **required** — image reference (see [images.md](images.md)) |
| `alt` | Alt text; empty string marks a decorative image |
| `title`, `caption`, `attr`, `attrlink` | Caption block, same semantics as the built-in |
| `link`, `target`, `rel` | Wrap the image in a link |
| `class` | Extra classes on the `<img>` (pass-through — not covered by the class-coverage test) |
| `width`, `height` | Intrinsic size attributes |
| `loading` | `lazy` (default) or `eager` |
| `quality` | WebP quality 1–100, default 78 |
| `role` | `card` / `illustration` (default) / `hero` — caps the variant width |

## map

Embedded third-party map frame. The theme itself ships zero external
requests — this shortcode is the explicit opt-in: nothing renders unless
the page passes an `https` embed URL.

| Parameter | Notes |
|---|---|
| `src` | **required** — `https` embed URL, e.g. `https://maps.google.com/maps?q=Shanghai&z=13&output=embed`; missing or non-`https` fails the build |
| `title` | Frame label, default `"Location map"` |

The frame loads lazily inside a 16/9 box.

## content/article

Embed another page's card inline.

| Parameter | Notes |
|---|---|
| `link` | Target page path, e.g. `/journal/x/`; empty means the current page. Unknown path: development warning, nothing rendered |
| `showSummary` | `true` / `false`; falls back to the target's front matter, then `site.Params.list.showSummary` |

`compactSummary` is **not supported** — every template silently ignores
it; the fixture smoke gate fails on it so it never sneaks back in.

## content/list

List recent pages as cards inside an article (the current page is excluded).

| Parameter | Notes |
|---|---|
| `limit` | How many pages, default `1` |
| `title` | Heading above the list; default "Recent articles" |
| `where`, `value` | Filter, e.g. `where="Type" value="journal"` |
| `cardView` | `true` for grid cards, `false`/absent for row cards |
| `summary` | Show each page's summary on its card, default `true` |

## content/icon

Inline an SVG from the site's `assets/icons/`.

```
{{</* icon "check" */>}}
```

Positional parameter: icon name. Missing file fails the build (the theme
ships no icon set).

## interactive/carousel

Image carousel with prev/next buttons, indicators and optional autoplay.

| Parameter | Notes |
|---|---|
| `images` | **required** — brace-wrapped list or globs: `"{gallery/a.webp, gallery/b*.webp}"` |
| `captions` | `"{key: caption, ...}"` keyed by file name, base name or path |
| `aspectRatio` | `W-H`, default `16-9` |
| `interval` | Autoplay step in ms, default `2000` |

First slide loads eagerly (possible LCP), the rest lazily. Two carousels on
one page stay independent.

## interactive/contact

Contact form posting to a JSON endpoint.

| Parameter | Notes |
|---|---|
| `action` | Endpoint, default `/api/contact` |
| `maxBytes` | Message limit shown by the live counter, default `1000` |

The endpoint must validate, sanitise and rate-limit server-side; the hidden
`hp_name` honeypot must be rejected when filled.

## interactive/cta

Call-to-action banner.

| Parameter | Notes |
|---|---|
| `title` | Default "Ready to get started?" |
| `subtitle` | Optional second line |
| `buttonText` | Default "Get Started" |
| `buttonUrl` | Default `/contact/` |
| `icon` | Name under `assets/icons/`; missing file: development warning, bare CTA still renders |

## interactive/email

Obfuscated mailto link (HTML entities, no JavaScript).

```
{{</* email user="info" domain="example.com" */>}}
```

Both parameters required; a missing one fails the build.

## ads

AdSense display unit. The loader ships in head only on pages using it.

```
{{</* ads slot="1234567890" */>}}
```

| Parameter | Notes |
|---|---|
| `slot` | Required ad slot ID |
| `format` | `data-ad-format`, default `auto` |

Requires site `[ads] client`; `static/ads.txt` must name the ID or the
build fails.

## layout/multi-col + layout/col-left, col-mid, col-right

Multi-column grid. Wrap content in `col-*` shortcodes inside `multi-col`.

| Parameter | Notes |
|---|---|
| `columns` | `2` (default) / `3` / `4` |
| `ratio` | `left:right` track weights for 2 columns, default `1:1` |
| `gap` | Grid gap, default `2rem` |
| `margin` | Outer margin, default `3rem 0` |
| `align` | `top` / `center` / `bottom` inside each column |

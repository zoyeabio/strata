---
title: "Customization"
description: "Colour schemes, CSS variables, custom CSS, and overriding templates and render hooks."
keywords: ["customization", "colour schemes", "css", "overrides"]
weight: 50
---

## Colour schemes

Seven schemes ship, each with light and dark variants. Select one with:

```toml
# params.toml
colorScheme = "ocean"
```

| Scheme | Character |
|---|---|
| `default` (default) | Blue, general purpose |
| `navy` | Deep navy, formal |
| `slate` | Grey-blue, editorial |
| `ocean` | Teal, calm |
| `forest` | Green, health and nature |
| `wine` | Burgundy, warm |
| `gold` | Amber, artisanal |

A typo in `colorScheme` fails the build and prints the name you wrote — it
never falls back silently. Every scheme defines both `:root` and
`:root.dark`, so `defaultAppearance` and the visitor toggle work with all
of them.

## Appearance

```toml
defaultAppearance = "light"   # light, dark, or auto to follow the OS
autoSwitchAppearance = true   # follow the OS until the visitor chooses
```

The theme stores the visitor's choice in `localStorage` and applies it
before first paint via an inline script, so there is no flash of the wrong
scheme.

## Custom CSS

```toml
customCSS = ["css/site.css"]   # asset paths, loaded after the theme
```

Place the file at `assets/css/site.css` in your site. It is fingerprinted
and served with an integrity attribute, same as the theme's own stylesheet.

## CSS variables

A scheme file sets these on `:root` (light) and `:root.dark`:

| Variable | Purpose |
|---|---|
| `--site-accent` | Primary accent (buttons, active nav) |
| `--site-accent-strong` | Hover/pressed accent |
| `--site-accent-soft` | Tinted surfaces, chips |
| `--site-surface-tint` | Subtle background wash |
| `--site-text-strong` | Headings |
| `--site-link` | Link colour |
| `--site-ring` | Focus ring |

Layout variables (rarely overridden) live in `assets/css/base/reset.css`:

| Variable | Default | Purpose |
|---|---|---|
| `--site-gutter` | 24 → 56 → 96 → 128px | Page gutter ladder at 640/853/1024px |
| `--site-content` | `1024px` | Content column cap |

To build a new scheme, copy `assets/css/schemes/default.css`,
rename it, adjust both light and dark blocks, and set `colorScheme` in the
site. Gate 39 checks contrast in both modes for every scheme, so a new
palette has to earn its colour rather than merely ship it. Prefer `customCSS`
overrides for small tweaks instead of forking a scheme file.

## Logo and header

```toml
logo = "images/logo.svg"          # asset path
disableTextInHeader = true        # hide the title once a logo is present
```

If the logo fails to resolve, the site title still renders — the header
never ends up empty.

## Typography overrides

The type scale is fixed in `assets/css/base/typography.css`; override
individual sizes from `customCSS` if you must. Changing the prose measure
(720px) is possible via `.prose { max-width: … }` but breaks the `sizes`
calculations on body images — prefer leaving it alone.

## Overriding templates

The theme's templates are ordinary files in `layouts/`. Hugo prefers your copy
when both exist at the same path, so overriding one is copying it into your
site's own `layouts/` and editing it there:

```
your-site/
  layouts/
    partials/
      page/
        series.html      # your copy wins over the theme's
```

The optional hooks in the [Site hooks](/docs/configuration/#site-hooks) table
are the ones you **add** rather than copy — each is called only when the file
exists.

### Your CSS already wins

The theme's rules live inside `@layer strata-base, strata-components`. A file
you add through `customCSS` is unlayered, and unlayered styles win over
layered ones at equal specificity. So you override the theme by repeating the
selector, not by reaching for `!important`:

```css
/* assets/css/site.css */
.card__summary {
  font-size: 15px;
}
```

This example site ships exactly one such file, `assets/css/example.css`, and
every rule in it styles markup the site emits itself through
`layouts/partials/`. Copying those two directories together is the whole
pattern — the site hooks, and the CSS that gives them shape.

### Two cautions

- **Keep a copied file's internal calls.** Most theme partials are called with
  a `dict` of arguments and return a specific shape. A half-rewritten partial
  fails the build with an error that names the caller, not the mistake.
- **No inline scripts.** `static/_headers` ships `script-src 'self'` with no
  `unsafe-inline`, so a `<script>` block in your markup is blocked by the
  browser. Reference a file from `assets/js/` and fingerprint it the way the
  theme does.

## Render hooks

Two files in `layouts/_default/_markup/` tell Goldmark how to emit links and
images. Unlike the optional partial hooks, the theme always provides both, so
copying one **replaces** it rather than adding to it.

### render-link.html

Without it, Goldmark emits a bare `<a>` that navigates the tab the reader is
reading in — a reference link takes them out of the article and they have to
come back to find their place. With `externalLinksNewTab = true` (the
default), a link to another host gains `target="_blank"` and a marker:

```html
<a href="https://example.com/" class="link--external" target="_blank" rel="noopener noreferrer">docs<span class="link__icon" aria-hidden="true">&#8599;&#65038;</span></a>
```

- **Any other host counts as external**, so a link between your own sites also
  opens a new tab. If you publish more than one site and cross-link them
  heavily, that is tab sprawl by design.
- Internal, `mailto:` and fragment links stay in the tab. Site navigation must
  stay in the tab or every header click would spawn a new one.
- Scheme-relative `//host` counts as external too. The check tests the full
  scheme, not a bare `http` prefix, so `httpfoo:bar` is not mistaken for a web
  link.
- The anchor gains `class="link--external"`, the hook for styling external
  links as a group. Without it a site would have to reach through the marker
  with `a:has(.link__icon)`.
- The marker is a real element, not `::after` content, so assistive technology
  skips it instead of reading "arrow" after every link. `&#65038;` is the text
  variation selector, which keeps the glyph out of emoji presentation.
- Restyle `.link__icon` or `a.link--external` from `customCSS`, or set
  `externalLinksNewTab = false` to drop both the new tab and the marker.

### render-image.html

Inline markdown images, `![alt](x)`, join the responsive pipeline instead of
falling through to Goldmark's plain `<img>`. They always resolve as
`role="illustration"`, so they never exceed the illustration ladder. Figures
are a separate concern and go through the `figure` shortcode, which takes an
explicit `role`. `alt` falls back to `title` when the markdown omits it.


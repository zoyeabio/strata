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
colorScheme = "paper"
```

| Scheme | Character |
|---|---|
| `default` (default) | Neutral blue, general purpose |
| `navy` | Deep blue, business and finance |
| `forest` | Green, nature, health and education |
| `wine` | Burgundy, editorial and culture |
| `paper` | Warm paper, long-form reading |
| `clay` | Warm earth, developers |
| `night` | High contrast, low vision |

A typo in `colorScheme` fails the build and prints the name you wrote — it
never falls back silently. Every scheme defines both `:root` and
`:root.dark`, so `defaultAppearance` and the visitor toggle work with all
of them. Warm or dark-first schemes such as `clay` pair well with
`defaultAppearance = "dark"`.

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

A scheme is a table of anchor values, set on `:root` (light) and
`:root.dark` (dark). Anchors are the only colour values in the theme — the
decorative colours are derived from them with `color-mix` in
`assets/css/base/palette.css`, so a palette file never carries a surface or
border scale of its own.

| Anchor | Purpose |
|---|---|
| `--site-page-bg` | Page ground |
| `--site-text` | Body text |
| `--site-text-muted` | Secondary text |
| `--site-text-faint` | Tertiary text, hints |
| `--site-text-strong` | Headings, emphasis |
| `--site-accent` | Button fill; must carry white text |
| `--site-accent-strong` | Button hover fill |
| `--site-accent-fg` | Accent read as text or icon. Dark blocks only |
| `--site-link` | Link colour |
| `--site-ring` | Focus ring |
| `--site-ok` | Success text |
| `--site-error` | Error text |

Derived from the anchors, read but not set:

| Variable | Mixed from |
|---|---|
| `--surface`, `--surface-hover` | `--text` over `--page-bg` |
| `--border`, `--border-strong` | `--text` over `--page-bg` |
| `--surface-tint`, `--accent-soft` | `--site-accent` over `--page-bg` |
| `--accent-fg` | `--site-accent-fg`, falling back to `--site-accent` |

Structural colours mix from `--text`, which keeps panels and rules neutral
whatever the brand hue. Brand colours mix from `--site-accent`, so a tinted
panel and a selection track sit in the same palette as the button they
point to.

`--site-accent` is a fill and `--site-accent-fg` is that same hue read as
text. A button needs a dark enough accent to hold a white label, and in dark
mode no single value is both dark enough for that and light enough to read
against the ground, so dark blocks set `--site-accent-fg` separately. Light
blocks omit it and inherit the accent.

Layout variables (rarely overridden) live in `assets/css/base/reset.css`:

| Variable | Default | Purpose |
|---|---|---|
| `--site-gutter` | 24 → 56 → 96 → 128px | Page gutter ladder at 640/853/1024px |
| `--site-content` | `1024px` | Content column cap |

To build a new scheme, copy `assets/css/schemes/default.css`,
rename it, and adjust both blocks. Gate 39 checks that every scheme
declares its anchors and that the resolved palette clears its contrast
floors in both modes, so a new palette has to earn its colour rather than
merely ship it. To change one value, set the anchor from `customCSS` instead
of forking a scheme file — the derivation picks the new value up on its own.

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


---
title: "Customization"
description: "Colour schemes, CSS variables, and adding your own CSS."
keywords: ["customization", "colour schemes", "css"]
weight: 50
---

## Colour schemes

Four schemes ship, each with light and dark variants. Select one with:

```toml
# params.toml
colorScheme = "strata-ocean"
```

| Scheme | Character |
|---|---|
| `strata-default` (default) | Neutral blue-grey |
| `strata-forest` | Deep green |
| `strata-ocean` | Cool blue |
| `strata-slate` | Warm grey |

A typo in `colorScheme` fails the build and prints the name you wrote — it
never falls back silently. Every scheme defines both `:root` and
`:root.dark`, so `defaultAppearance` and the visitor toggle work with all
of them.

## Appearance

```toml
defaultAppearance = "light"   # or "dark"
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

To build a new scheme, copy `assets/css/schemes/strata-default.css`,
rename it, adjust both light and dark blocks, and set `colorScheme` in the
site. Prefer `customCSS` overrides for small tweaks instead of forking a
scheme file.

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

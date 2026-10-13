---
title: "Typography"
description: "The type scale, the prose width, and the system font stack."
keywords: ["typography", "type", "fonts"]
weight: 40
---

## Font stack

No webfonts. The theme ships zero font files and makes zero network
requests; text renders in the platform stack:

| Role | Stack |
|---|---|
| Body | `system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif` |
| Prose (article body) | same system stack |
| Code / `pre` | `ui-monospace, SFMono-Regular, Menlo, Consolas, monospace` |

Rationale: privacy (no third-party font CDN), performance (no font download
or FOUT), and consistent rendering on the sites that matter — documentation
and scientific publishing.

## Measure

- Article body (`.prose`) is capped at **720px**
- Landing pages lift that cap entirely: the home page renders its content as
  `.page-content .prose .page--wide`, so full-width shortcodes (hero carousel,
  grids, card rows) **and** the paragraphs around them use the whole column.
  The 720px measure is for long-form reading; a landing page carries short
  marketing blocks, where the cap only leaves dead air at the right edge.
  The same `.page--wide` token is what a non-article single page receives
- Site content column caps at **1024px** with responsive gutters
  (24px → 56px → 96px → 128px at 640/853/1024px breakpoints)
- Card rows and grids use the same column width ladder

## Scale

Sizes in rem, anchored on the browser default (16px):

| Element | Size | Line height |
|---|---|---|
| h1 | 1.875rem (30px), weight 700 | 1.25 |
| h2 | 1.5rem (24px) | 1.3 |
| h3 | 1.1875rem (19px) | 1.35 |
| h4 | 1.0625rem (17px) | 1.4 |
| h5 / h6 | 0.9375rem (15px) | — |
| Article body (`.prose`) | 17px, 18px from 1280px | 1.7 |
| Term list rows | base, 16px from 1280px | 1.85 |

`html { font-size: 100% }` — the scale follows the visitor's browser
setting, including increased-default-size accessibility preferences.

## RTL

`rtl = true` in site params flips `<html dir="rtl">`. The layout uses
logical properties, so padding, margins and text alignment mirror
automatically.

---
title: "Images"
description: "Storage rules, resolution order, the variant ladder, and image roles."
keywords: ["images", "pipeline", "ladder", "roles"]
weight: 30
---

## Page layout

Articles are **page bundles**: `content/{section}/{slug}/index.md`. That is
the layout `place-image.sh` and the image resolver assume. A leaf page
`content/{section}/post.md` is supported by the resolver too, but its images
resolve to `assets/images/{section}/`, not to a `{slug}/` subdirectory.

## Storage

- Site-wide images: `assets/images/…`
- Section-owned images: `assets/images/{section}/…`
- Per-article bundle images: `assets/images/{section}/{slug}/…` (the
  `place-image.sh` target for `content/{section}/{slug}/index.md`)
- Or inside the page bundle as a sibling of `index.md` — discovered by name
  when no `featureimage` is declared, see [Which image a page renders](#which-image-a-page-renders)

## Resolution order

Every reference (`featureimage`, figure shortcode, markdown image) resolves
in this order:

1. Page bundle resource
2. The reference as written (assets path or relative path)
3. `assets/images/{pageDir}/…` — the article's own directory
4. `assets/images/…`
5. `static/…` (served untouched)
6. Not found — **production builds fail** with an error naming the reference;
   `hugo server` only warns. A page with no image declared is not an error.

`https://` sources pass through only when `allowRemoteImages = true`;
otherwise they are skipped with a development warning.

## Which image a page renders

A page declares `featureimage`. Without it, the theme still finds an image
when the page bundle holds a resource whose name contains `feature`, `cover`
or `thumbnail` — so `content/science/manufacturing/index.md` plus a sibling
`featured.jpg` needs no front matter key at all. The chain is:

1. `featureimage`
2. bundle resource named `feature*`, `cover*`, `thumbnail*`

Cards, term cards and page heroes all take the same reference. Open Graph and
schema take it too, with `images` a social-only fallback: `images[0]` is used
only when `featureimage` is absent, then the bundle resource, then
`site.Params.defaultSocialImage`. `featureimage` still beats `images` so the
picture a page shows is the picture it advertises.

## Variant ladder

Bitmap images (JPEG/PNG) are encoded as WebP at the ladder widths —
`[params.image].ladder`, 480 / 800 / 1280 / 1920 by default — each step capped
by the source width and by the image role, de-duplicated, and a step less than
15% wider than its predecessor is dropped. Results:

- at most four responsive WebP files per source
- never two near-identical widths
- one quality everywhere (`[params.image].quality`, WebP q78 by default), so
  one width is never stored twice at two qualities

A source reused across roles shares those transforms. A feature image may add
one fixed 1200×630 social JPEG, so the build gate allows no more than five
derived files per source in total.

SVG, GIF and animated WebP bypass processing entirely (the pipeline would
flatten animations to frame one). `disableImageOptimization = true` returns
the original file for every role.

## Roles

| Role | Widest variant | Used by |
|---|---|---|
| `card` | 800 | list/term cards |
| `illustration` (default) | 1600 | body figures, markdown images |
| `hero` | 1600 | article hero, with preload |
| `og` | 1200×630 JPEG fill | Open Graph / Twitter card |

The caps are `[params.image].caps.*` and the preview size is
`[params.image].og.width` / `.height`, both overridable per site.

The hero is cropped to a fixed height rather than letterboxed, so an image of
any aspect ratio fills its frame. The height is `--page-hero-height`
(200 / 260 / 300px by breakpoint); override the variable to change the crop.

## SciVisual handoff

Use one 1600×900 Hero source for the article hero, 16:9 cards and the generated
1200×630 social preview. The article hero is a shallower centre crop, so keep
the essential subject in the central horizontal band and do not place text or
critical anatomy near the top or bottom edge.

The example posts demonstrate this contract with the 1600×900 `features-*.png`
sources. The wider, shallower `hero-*.png` files belong to section and docs
banners; they demonstrate that the renderer also accepts purpose-built banner
art, not a second required article-Hero size.

SciVisual article illustrations also arrive at 1600×900 by default. Strata
preserves their aspect ratio and emits WebP variants up to 1600px; 16:9 is the
common production profile, not a requirement for mechanisms, charts or taller
figures. Keep generated sources as PNG when they contain labels or precise
graphics, and use high-quality JPEG for photographic work. The deployed page
still receives responsive WebP, while the source format remains an authoring
choice.

## Front matter

| Key | Effect |
|---|---|
| `featureimage` | Card image; also the article hero on single pages |
| `featureimagealt` | Alt text; fallback `Featured image for {title}` |
| `showHero: false` | Keep the card image, suppress the hero on the single page |

## Per-figure role

The `figure` shortcode's `role` parameter caps one figure's widest variant
without changing the site-wide caps. Quality has no such override — it is
`[params.image].quality` everywhere, which is what keeps a width from being
stored twice.

## Focus / cropping

`og` fills are always 1200×630 (centre crop). Variant resizing never crops —
aspect ratio is preserved.

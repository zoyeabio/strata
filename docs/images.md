# Images

## Storage

- Site-wide images: `assets/images/…`
- Section-owned images: `assets/images/{section}/…`
- Per-page bundle images: next to `index.md` in the page bundle

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

## Variant ladder

Bitmap images (JPEG/PNG) are encoded as WebP at widths 480, 800, 1280, 1920,
each step capped by the source width and by the image role, de-duplicated,
and a step less than 15% wider than its predecessor is dropped. Results:

- at most four files per image
- never two near-identical widths
- one quality everywhere (WebP q78 by default), so one width is never stored
  twice at two qualities

SVG, GIF and animated WebP bypass processing entirely (the pipeline would
flatten animations to frame one). `disableImageOptimization = true` returns
the original file for every role.

## Roles

| Role | Widest variant | Used by |
|---|---|---|
| `card` | 800 | list/term cards |
| `illustration` (default) | 1280 | body figures, markdown images |
| `hero` | 1920 | article hero, with preload |
| `og` | 1200×630 JPEG fill | Open Graph / Twitter card |

## Front matter

| Key | Effect |
|---|---|
| `featureimage` | Card image; also the article hero on single pages |
| `featureimagealt` | Alt text; fallback `Featured image for {title}` |
| `showHero: false` | Keep the card image, suppress the hero on the single page |

## Shortcode quality

The `figure` shortcode accepts `quality` (1–100, default 78) and `role`
(`card` / `illustration` / `hero`) to override the defaults for scientific
figures that need sharper text.

## Focus / cropping

`og` fills are always 1200×630 (centre crop). Variant resizing never crops —
aspect ratio is preserved. Per-image focal-point cropping (`focus` front
matter) is planned, not shipped.

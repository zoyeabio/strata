---
title: "Shortcodes"
description: "Every Strata shortcode with the exact syntax, the full parameter list, and a live example of each."
keywords: ["shortcodes", "reference", "syntax", "hugo"]
featureimage: "images/hero-shortcodes.png"
featureimagealt: "A grid of small marks over a dark field"
---

Fourteen shortcodes. Every one below is live — `ads` apart, which needs a
publisher ID — and each block shows the exact syntax it was written with.

---

## `figure`

Images go through the responsive pipeline, so a figure carries a `srcset`
and a `sizes`. `role` caps the widest variant. Quality is a site-wide
setting, so one width is never stored twice at two qualities.

{{< figure src="images/diagram-nodes.png" alt="Five connected nodes of varying size" title="A figure, fully annotated" caption="**Caption** accepts *markdown*, as does the attribution." attr="Diagram by Strata Studio" attrlink="https://github.com/zoyeabio" link="/features/" target="_blank" rel="noopener" class="figure--annotated" loading="lazy" role="illustration" >}}

<pre><code>{{&lt; figure src="images/diagram-nodes.png" alt="Five connected nodes"
  title="A figure, fully annotated" caption="**Markdown** in the caption."
  attr="Diagram by Strata Studio" attrlink="https://github.com/zoyeabio"
  link="/features/" target="_blank" rel="noopener"
  class="figure--annotated" loading="lazy" role="illustration" &gt;}}</code></pre>

| Parameter | Required | Notes |
|---|---|---|
| `src` | yes | Fails the build when absent |
| `alt`, `title`, `caption`, `attr`, `attrlink` | | Caption and attr are markdown |
| `link`, `target`, `rel` | | Wrap the image; `_blank` adds `rel="noopener"` |
| `class` | | Appended to `figure` |
| `width`, `height` | | Override the intrinsic variant size |
| `loading` | | `lazy` by default, or `eager` |
| `role` | | `hero`, `card`, `illustration`; caps the ladder |

---

## `interactive/carousel`

Slides run through the same pipeline. `fit="contain"` keeps a chart's
axes on screen instead of cropping them.

{{< interactive/carousel images="{images/carousel-one.png, images/carousel-two.png, images/carousel-three.png}" captions="{carousel-one.png: First slide, carousel-two.png: Second slide, carousel-three.png: Third slide}" alts="{carousel-one.png: A warm composition over a dark field, carousel-two.png: The same composition rotated, carousel-three.png: A third composition at right angles}" fit="cover" aspectRatio="16-9" interval="2500" >}}

The charts below use `contain`, because `cover` would crop their axes off
at a narrow frame:

{{< interactive/carousel images="{images/chart-bars.png, images/chart-lines.png}" captions="{chart-bars.png: Bar chart, cropped by cover, chart-lines.png: Line chart, contained}" alts="{chart-bars.png: Eight bars rising to the right, chart-lines.png: Two crossing lines over a pale ground}" fit="contain" aspectRatio="16-9" >}}

<pre><code>{{&lt; interactive/carousel images="{images/carousel-one.png, images/carousel-two.png}"
  captions="{carousel-one.png: First slide, carousel-two.png: Second slide}"
  alts="{carousel-one.png: A description of the first slide}"
  fit="cover" aspectRatio="16-9" interval="2500" &gt;}}</code></pre>

| Parameter | Required | Notes |
|---|---|---|
| `images` | yes | Brace-wrapped, comma-separated names or globs |
| `captions` | | `{key: value, ...}`; first colon splits |
| `alts` | | Same shape; per-slide alt text |
| `fit` | | `cover` (default) or `contain`; anything else becomes `cover` |
| `aspectRatio` | | `W-H`, default `16-9` |
| `interval` | | Autoplay step in ms, default 2000 |

---

## `content/list`

Lists pages as cards. `where` and `value` filter `site.RegularPages`.

{{< content/list limit="2" title="Recent posts, filtered" where="Section" value="posts" cardView="true" summary="true" >}}

<pre><code>{{&lt; content/list limit="2" title="Recent posts" where="Section" value="posts"
  cardView="true" summary="true" &gt;}}</code></pre>

| Parameter | Default | Notes |
|---|---|---|
| `limit` | 1 | Pages to consider |
| `title` | i18n fallback | Heading above the list |
| `where`, `value` | none | Filter field and expected value |
| `cardView` | `false` | `true` renders a grid |
| `summary` | `true` | `false` hides each summary |

The page containing the shortcode never appears in its own list.

---

## `content/article`

A single page, rendered as a card.

{{< content/article link="/posts/shipping-images-that-load/" showSummary="true" >}}

<pre><code>{{&lt; content/article link="/posts/shipping-images-that-load/" showSummary="true" &gt;}}</code></pre>

| Parameter | Default | Notes |
|---|---|---|
| `link` | the current page | Fails quietly if it does not resolve |
| `showSummary` | site setting | Override the page's own `showsummary` |

---

## `content/icon`

Inline SVG from `assets/icons/`. Positional, so the name is the only
argument.

{{< content/icon "sun" >}} {{< content/icon "moon" >}} {{< content/icon "search" >}} {{< content/icon "linkedin" >}} {{< content/icon "instagram" >}} {{< content/icon "facebook" >}} {{< content/icon "whatsapp" >}} {{< content/icon "email" >}} {{< content/icon "bars" >}}

<pre><code>{{&lt; content/icon "sun" &gt;}}</code></pre>

Nine icons ship: `bars`, `email`, `facebook`, `instagram`, `linkedin`,
`moon`, `search`, `sun`, `whatsapp`. Drop another SVG into
`assets/icons/` and its filename becomes its name. A missing icon fails
the build.

---

## `interactive/email`

Renders an address without exposing it to harvesters.

{{< interactive/email user="hello" domain="strata.example" >}}

<pre><code>{{&lt; interactive/email user="hello" domain="strata.example" &gt;}}</code></pre>

Both `user` and `domain` are required.

---

## `interactive/contact`

Posts to a JSON endpoint. The message field carries a live byte counter and
a honeypot input for naive bots; the script selects every form by attribute,
so several forms on one page do not collide.

{{< interactive/contact action="/api/contact" maxBytes="600" >}}

<pre><code>{{&lt; interactive/contact action="/api/contact" maxBytes="600" &gt;}}</code></pre>

| Parameter | Default | Notes |
|---|---|---|
| `action` | `/api/contact` | Endpoint the form posts to |
| `maxBytes` | `1000` | Limit shown by the counter |

The endpoint must validate, sanitise and rate-limit on the server and reject a
filled `hp_name` honeypot. This is the same form as on
[the contact page](/contact/).

---

## `interactive/cta`

A call to action with an optional icon and link.

{{< interactive/cta title="Ship it." subtitle="A single CTA, with the icon parameter wired." buttonText="Read the docs" buttonUrl="/docs/" icon="search" >}}

<pre><code>{{&lt; interactive/cta title="Ship it." subtitle="With the icon parameter wired."
  buttonText="Read the docs" buttonUrl="/docs/" icon="search" &gt;}}</code></pre>

| Parameter | Default |
|---|---|
| `title` | `Ready to get started?` |
| `subtitle` | none |
| `buttonText` | `Get Started` |
| `buttonUrl` | `/contact/` |
| `buttonTarget`, `buttonRel` | none |
| `icon` | none; a missing SVG is skipped, not fatal |

---

## `layout/multi-col`

`columns` is 2, 3 or 4. `ratio` applies to two columns only. Nested
content is trusted HTML, so a nested shortcode works here — unlike inside
a `col`, where the inner text is markdownified.

{{< layout/multi-col columns="2" ratio="1:1" gap="2rem" margin="3rem 0" align="top" >}}
{{< layout/col-left >}}
### Two columns

The `col` shortcodes receive their inner content through `markdownify`, so
markdown works inside them and shortcodes do not. Use this page for the
outer structure and put a shortcode outside the columns if you need one.
{{< /layout/col-left >}}
{{< layout/col-right >}}
### And they are separate

Each column is a sibling. A missing column leaves its neighbour, it does
not stretch it.
{{< /layout/col-right >}}
{{< /layout/multi-col >}}

<pre><code>{{&lt; layout/multi-col columns="2" ratio="1:1" align="top" &gt;}}
{{&lt; layout/col-left &gt;}}Left{{&lt; /layout/col-left &gt;}}
{{&lt; layout/col-right &gt;}}Right{{&lt; /layout/col-right &gt;}}
{{&lt; /layout/multi-col &gt;}}</code></pre>

| Parameter | Default | Notes |
|---|---|---|
| `columns` | `2` | `2`, `3` or `4`; anything else falls back to `2` |
| `ratio` | `1:1` | Two columns only; ignored at 3 and 4 |
| `gap`, `margin` | `2rem`, `3rem 0` | |
| `align` | `top` | `top`, `center`, `bottom` |

Three columns use `col-mid`. `columns="4"` needs a fourth wrapper and there is
no fourth shortcode, so repeat `col-right` — it renders the same `.mcol`.

{{< layout/multi-col columns="3" gap="1.5rem" >}}
{{< layout/col-left >}}
### One third

The middle wrapper is `col-mid`, not `col-right` reused.
{{< /layout/col-left >}}
{{< layout/col-mid >}}
### Another third

Three tracks split evenly; `ratio` has no effect here.
{{< /layout/col-mid >}}
{{< layout/col-right >}}
### And a third

All three stay top-aligned at any width.
{{< /layout/col-right >}}
{{< /layout/multi-col >}}

<pre><code>{{&lt; layout/multi-col columns="3" gap="1.5rem" &gt;}}
{{&lt; layout/col-left &gt;}}Left{{&lt; /layout/col-left &gt;}}
{{&lt; layout/col-mid &gt;}}Middle{{&lt; /layout/col-mid &gt;}}
{{&lt; layout/col-right &gt;}}Right{{&lt; /layout/col-right &gt;}}
{{&lt; /layout/multi-col &gt;}}</code></pre>

---

## `map`

An embedded map. `src` must start with `https://`.

{{< map src="https://www.openstreetmap.org/export/embed.html?bbox=-122.69%2C45.505%2C-122.655%2C45.525&layer=mapnik" title="Strata Studio, Portland" >}}

<pre><code>{{&lt; map src="https://www.openstreetmap.org/export/embed.html?bbox=..."
  title="Strata Studio, Portland" &gt;}}</code></pre>

---

## `ads`

Not shown live: the theme keeps its head free of third-party requests by
default, and AdSense is the one sanctioned exception. It only loads on a
page that carries an ad unit, and only when `site.Params.ads.client` is
set — so a demo that used it would break the very property it exists to
show.

<pre><code>{{&lt; ads slot="1234567890" format="auto" minHeight="250" &gt;}}</code></pre>

```toml
# config/_default/params.toml
[ads]
  client = "ca-pub-0000000000000000"
```

| Parameter | Required | Notes |
|---|---|---|
| `slot` | yes | Fails the build when absent |
| `format` | | Default `auto` |
| `minHeight` | | Passed to the ad slot |

`site.Params.ads.client` must be set, or the shortcode fails the build.

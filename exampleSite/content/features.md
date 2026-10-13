---
title: "Features"
description: "What Strata does on your behalf: responsive image ladders, a closed head, social cards that match the page, typographic defaults, and a build that fails loudly."
keywords: ["features", "responsive images", "seo", "performance", "typography"]
featureimage: "images/hero-features.png"
featureimagealt: "A wide feature banner with warm light over a dark field"
---

Five positions, one template. Each one is the answer to something we have
had to rebuild on every project, and each is turned on by default because
you should not have to remember to turn it on.

## Responsive images, resolved at build time

A single source becomes a ladder of WebP variants, capped by role. A card
never asks for more than 800px, an illustration 1280px, a hero 1920px.
Steps that would land within 15% of the one before them are dropped, so a
page never ships two near-identical widths, and never more than four
files per image.

{{< figure src="images/features-responsive.png" alt="A responsive composition across three breakpoints" caption="One source, four widths, three of which were within 15% of their neighbour and were dropped." role="illustration" loading="lazy" >}}

## The head stays closed

No web font, no analytics, no third-party script, no icon CDN. The
stylesheet is one file, compiled in-process and fingerprinted. Scripts are
applied before first paint so a stored dark-mode preference and a stored
reduce-motion preference never cost a frame.

{{< figure src="images/features-darkmode.png" alt="A dark interface under moonlight" caption="Appearance is applied before first paint. The switcher is in the footer." role="illustration" loading="lazy" >}}

## Social cards that tell the truth

The image in your share preview is the image on the page, because both come
from the same resolved resource. Same for JSON-LD: the Article schema
carries the preview image and the widest hero variant, and the description
is the page's own, never a site-wide string.

{{< figure src="images/features-seo.png" alt="Structured data flowing into a search result" caption="OG image and Article schema resolve through the same partial." role="illustration" loading="lazy" >}}

## Copy is the product

The prose styles are the point. Headings hold a rhythm, links are obvious,
code is readable, and the reading column is narrow. Dark mode carries its
own palette rather than inverting a light one.

{{< figure src="images/features-images.png" alt="A typeset page with generous margins" caption="Narrow column, generous measure. The reading width is a setting, not a fight." role="illustration" loading="lazy" >}}

## A build that fails loudly

A declared image that resolves to nothing fails the production build.
Same for a figure without a source. The development server warns instead,
so you learn in one session and not at deploy time.

{{< figure src="images/features-gates.png" alt="A pipeline with a clear pass and a clear stop" caption="Missing images fail `hugo build` and warn under `hugo server`." role="illustration" loading="lazy" >}}

## Scaffolding that stays yours

A single script writes a new site against this theme: config, menus,
footer, one content bundle, and the image directory. You inherit the gates
and never inherit the demo content.

{{< figure src="images/features-scaffold.png" alt="A fresh directory tree laid out cleanly" caption="`scripts/new-site.sh` writes a site against this theme in one pass." role="illustration" loading="lazy" >}}

---

{{< interactive/cta title="See the syntax." subtitle="Every shortcode, with the exact parameters." buttonText="Shortcode reference" buttonUrl="/shortcodes/" >}}

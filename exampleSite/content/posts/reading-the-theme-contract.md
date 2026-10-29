---
title: "Reading the theme contract"
description: "A theme is a promise about where the work sits. Reading it is reading which decisions are yours and which are settled."
date: 2026-03-05
tags: ["theming", "process"]
series: ["Foundations"]
weight: 3
keywords: ["theming", "contracts", "hugo"]
showtoc: true
featureimage: "images/features-scaffold.png"
featureimagealt: "A fresh directory tree laid out cleanly"
---

{{< ads slot="1234567890" >}}

A theme is a promise about where the work sits. Reading it is reading
which decisions are yours and which are already settled.

Strata settles most of them on purpose. The list of settled decisions is
short, and it is worth knowing it before you start, because you will stop
fighting things that are not negotiable.

## What Strata settles

- **The reading column is narrow.** The prose styles own the measure. You
  do not set it per page.
- **Images are resolved at build time.** You write one reference and the
  pipeline makes the variants. You do not write a `srcset` by hand.
- **The head has no remote requests.** No web font, no analytics, no icon
  CDN. AdSense is the one exception, and it is opt-in per page.
- **Social output mirrors the page.** The share image and the Article
  schema come from the same resolved resource the page shows.

Everything else is yours.

## What is yours

The things that are yours fall into three places:

1. **Config.** Brand, colour scheme, menus, footer, sharing links,
   pagination size. Plain TOML in `config/_default/`.
2. **Content.** Front matter decides the rest of a page's behaviour:
   whether it shows an author, whether the date is shown, whether it is
   in a series.
3. **Overrides.** Drop a template into your own `layouts/` and Hugo uses
   yours. The theme is a module, so anything not overridden falls through
   to it.

Notice that the third one is not a fork. You override the one template
that is wrong, and you keep the other thirty.

## The gate is part of the contract

A theme that does not fail loudly is a theme that quietly regresses.
Strata fails the production build when a declared image resolves to
nothing, and it warns under the development server instead. That is a
decision you should not have to make for yourself.

So when you read a theme, read what it refuses. A theme that will not
ship a broken image is telling you how much it expects of you.

```toml
# The build fails here, not at deploy time.
featureimage = "images/a-file-that-does-not-exist.png"
```

## Reading it quickly

Three files tell you most of what a theme is:

- `theme.toml` — the promise, and the minimum Hugo version.
- `layouts/_default/single.html` — what a page is, end to end.
- `layouts/partials/data/` — the resolver chain. This is where the
  decisions live, and where they are easiest to find.

Read those three and you know where to push back.

---

{{< interactive/cta title="The docs, in order." subtitle="Install, configure, then customise." buttonText="Start installing" buttonUrl="/docs/installation/" >}}

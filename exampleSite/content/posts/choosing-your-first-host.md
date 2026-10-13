---
title: "Choosing your first host"
description: "A static site has one real requirement from its host: a URL that does not change. Everything else is convenience."
date: 2026-02-11
tags: ["hosting", "process"]
series: ["Foundations"]
weight: 2
keywords: ["hosting", "static sites", "static hosting"]
featureimage: "images/features-gates.png"
featureimagealt: "A pipeline with a clear pass and a clear stop"
---

A static site has one real requirement from its host: a URL that does not
change. Everything else is convenience.

This is a useful thing to know, because it means almost any host will do,
and it means the wrong choice is rarer than you think.

## The two requirements

Everything under both of these is negotiable:

1. **The URL must not change.** Not the domain, but the path. A page you
   publish at `/notes/on-type/` should still be at `/notes/on-type/` in
   five years, because people will have linked to it.
2. **It must serve `index.html` at `/`.** Boring, but it is the one place
   a host can quietly break your home page.

Everything else is a trade.

## What is actually worth paying for

A CDN is worth it if you have readers outside your own country. It is the
single biggest thing a host does for a small site, and it is free at
roughly every option.

A custom domain is worth the year it costs. The cost is trivial and the
benefit is a URL you can keep.

Everything else is a convenience you are buying with an obligation. An
editor, a preview environment, a deployment pipeline — each one is a thing
you have to keep using correctly forever.

## The migration trap

The reason host choice matters is not performance. It is what you do when
you leave. A static site leaves cleanly, which is the whole point: the
files are yours, and a move is a copy. The danger is anything that turned
your static site into something else — a preview system that rewrites
your permalinks, an analytics tool that became the source of truth for
your numbers, a search index you cannot rebuild from the content.

Build the habit of being able to leave. A site you can leave is a site
you can stay on.

```bash
# The whole migration.
rsync -a --delete public/ dest:/var/www/site/
```

## A default

If you have no reason otherwise: a static host with a CDN and a custom
domain. Set the `baseURL` once, point it at the real domain, and do not
change it again.

That is the entire job.

---

{{< interactive/cta title="Read the next piece in the series." subtitle="What the theme asks of you, and what it does for you." buttonText="Reading the theme contract" buttonUrl="/posts/reading-the-theme-contract/" >}}

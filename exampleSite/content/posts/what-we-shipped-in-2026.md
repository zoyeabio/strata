---
title: "What we shipped in 2026"
description: "A short list of what changed on this site this year, and why each of it matters more than it looks."
date: 2026-07-30
lastmod: 2026-09-14
showdateupdated: true
tags: ["design", "performance"]
keywords: ["2026", "changes", "shipping"]
featureimage: "images/diagram-nodes.png"
featureimagealt: "A diagram of five connected nodes"
---

A short list of what changed on this site this year. Each item is small.
None of them were easy.

The reason to write this is that the useful work on a site is invisible
until it stops being true, and then it is too late to have written it down.

## The image pipeline got a role

Every image now declares what it is for: a hero, a card, or an
illustration. Each role caps the widest variant it will ever be asked for.

Before this, an image was whatever you happened to put it in, and a card
would sometimes be asked for a 1920px file because the source was wide.
It worked. It also meant the cards were slow and nobody could say why.

One word in the shortcode, and the cards stopped shipping four kilobytes
of extra file each.

## The head closed up

Two things left the head this year. The icon font, which became inline
SVG files that are fetched only when a page uses them. And the analytics
script, which was never earning its keep and whose absence nobody noticed.

The head is now one stylesheet and a couple of small scripts, all local,
all fingerprinted. The number went down by more than we expected.

## Related content started working

Related links had been broken for a while. They pointed at pages that
shared no tags, which made them a random list with a heading.

We fixed it by fixing the tags, not the algorithm. Three posts now share
a real series, and the ones that share a subject share a tag. The
feature was already correct; the data was not.

This is the most common kind of bug on a content site. The template is
fine, the data is not, and the fix is an afternoon of front matter.

## The build started failing

A missing image used to be a warning under the development server and a
silently empty figure in production. It is now an error in production and
a warning under development.

That sounds like the same thing. It is not. A build that fails tells you
before you ship. A build that warns tells you after, in a page load you
will not remember.

```bash
# This used to ship. Now it does not.
$ hugo --minify
ERROR: strata: image not found (ref="images/gone.png" role="hero")
```

## What we did not ship

A search backend, a newsletter form, a theme switcher with a gradient,
and a dark mode that tries to be clever about accent colours. All of them
were on a list for a long time, and none of them were worth having.

That list is worth keeping. It is easier to write down what you declined
while you remember why.

---

{{< interactive/cta title="More from the studio." subtitle="The Foundations series, in order." buttonText="Start at the beginning" buttonUrl="/posts/designing-a-small-site/" >}}

---
title: "Shipping images that load"
description: "Images are the bottleneck. The fix is not lazy-loading; it is deciding what the image is for before you optimise it."
summary: "Lazy-loading is the wrong answer to slow pages. The right one is deciding, before you optimise anything, what each image is actually there for."
date: 2026-05-21
tags: ["images", "performance"]
keywords: ["images", "performance", "webp", "responsive"]
author: "Strata Studio"
featureimage: "images/features-images.png"
featureimagealt: "An illustration with generous margins"
---

Images are the bottleneck. That has been true for a decade and it is
still true, because everything else got faster and images did not.

The usual answer is lazy-loading, and it is mostly the wrong answer.

## Why lazy-loading is not the fix

Lazy-loading moves work later. It does not reduce work. A page with eight
heavy images and lazy-loading still downloads eight heavy images, just
after the fold and just when the reader is scrolling for them.

The reader is not coming back up. They are deciding whether to keep
reading, and they are deciding it from a page that is still busy.

> Lazy-loading is the technique you reach for when you have already
> chosen the wrong images.

The order is the opposite: decide what the image is for, and then the
weight follows.

## What the image is for

There are three jobs, and each one has a different answer.

- **A card image** is a thumbnail. It is 400 to 600 pixels wide and
  nobody is reading it. Serve something small.
- **An illustration** is something the reader might actually look at.
  Start with a 1600-pixel-wide source so it stays clear in the reading column.
- **A hero** is a band of atmosphere behind text. It does not need to be
  sharp. It needs to be fast, because it is the first thing painted.

Once you know which one it is, the size is a number, not a negotiation.

## The ladder, and why it stops

A responsive ladder gives you one file per width you actually need. The
trap is too many widths: 480, 640, 800, 960, 1120, 1280, 1600, 1920.
Each of those is a request and a build step, and several of them are
within a few percent of each other, so a phone that could have taken the
800 variant took the 640 and no one noticed.

The rule that fixes it: **drop any step that is less than 15% wider than
the one before it.** You keep the variety where it matters and you stop
paying for the near-duplicates.

```text
ladder  480  800  1280  1920
cap     card 800  illustration 1600  hero 1600
```

## WebP is not the argument

The argument is the format. WebP at 78 is small enough that the format
choice barely matters at card size, and sharp enough at hero size that
nobody will notice. The quality number is a setting; pick one, apply it
to everything, and stop optimising it per image.

## What actually moves the number

If you want the page faster, do these in order:

1. Fewer images. The biggest one.
2. Smaller images, by role, not by guess.
3. A ladder with fewer steps.
4. A quality number that is not 100.

Then, and only then, the `loading` attribute.

{{< figure src="images/chart-bars.png" alt="A bar chart with eight ascending bars" caption="The biggest bar is the one you remove." loading="lazy" role="illustration" >}}

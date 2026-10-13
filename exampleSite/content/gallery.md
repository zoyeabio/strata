---
title: "Gallery"
description: "The Strata image pipeline in one page: a responsive ladder, a role cap, and the difference between cover and contain."
keywords: ["gallery", "images", "crop", "responsive", "pipeline"]
featureimage: "images/hero-gallery.png"
featureimagealt: "A warm field lit from behind"
---

Every image on this page comes from one file. The pipeline picks the
right variant for the frame it lands in, and nothing else changes between
a phone and a desktop.

## The frame decides

A hero is a wide band, not a rectangle. The theme caps the widest variant
at 1920px, because a hero that would be 3840px wide is still shown at
1920px: it only costs bytes.

```
cap:  hero 1920  ·  illustration 1280  ·  card 800
ladder: 480 800 1280 1920
steps within 15% of their predecessor are dropped
```

## Cover and contain

`cover` fills the frame and crops. `contain` fits inside it and leaves a
ground. Which one you want depends on what matters: a photograph wants
cover, a chart wants contain, because a chart's axes are content.

{{< interactive/carousel images="{images/carousel-one.png, images/carousel-two.png, images/carousel-three.png}" captions="{carousel-one.png: Cover — the frame is filled, the edges crop, carousel-two.png: Cover, a wider composition, carousel-three.png: Cover, cropped harder at a narrow frame}" alts="{carousel-one.png: A warm composition over a dark field, carousel-two.png: The composition rotated a quarter turn, carousel-three.png: The composition at right angles}" fit="cover" aspectRatio="16-9" interval="2600" >}}

{{< interactive/carousel images="{images/chart-bars.png, images/chart-lines.png, images/diagram-nodes.png}" captions="{chart-bars.png: Contain — the axes stay, chart-lines.png: Two series, both legends visible, diagram-nodes.png: A diagram, labels intact}" alts="{chart-bars.png: Eight bars rising to the right, chart-lines.png: Two crossing lines on a pale ground, diagram-nodes.png: Five connected nodes}" fit="contain" aspectRatio="16-9" >}}

## Aspect ratios that do not match

A source rarely has the aspect ratio a frame wants. The pipeline resizes,
it never stretches, so nothing is distorted. These two have deliberately
useful ratios: one is square, one is portrait.

{{< layout/multi-col columns="2" ratio="1:1" align="top" >}}
{{< layout/col-left >}}
A 1:1 source, asked to sit in a wide frame.
{{< /layout/col-left >}}
{{< layout/col-right >}}
A 9:16 source, asked to sit in the same frame.
{{< /layout/col-right >}}
{{< /layout/multi-col >}}

{{< layout/multi-col columns="2" ratio="1:1" align="top" >}}
{{< layout/col-left >}}
{{< figure src="images/square-portrait.png" alt="A square composition of concentric rings" caption="1:1 source." role="illustration" loading="lazy" >}}
{{< /layout/col-left >}}
{{< layout/col-right >}}
{{< figure src="images/tall-crop.png" alt="A tall composition fading from warm to dark" caption="9:16 source." role="illustration" loading="lazy" >}}
{{< /layout/col-right >}}
{{< /layout/multi-col >}}

## The illustration role

Body figures are capped at 1280px. Wider than that and the extra pixels
are invisible in a narrow column, so they are simply not generated.

{{< figure src="images/texture-weave.png" alt="A woven texture of small marks over a gradient" caption="An illustration: capped at 1280px, three variants on the ladder." role="illustration" loading="lazy" >}}

{{< figure src="images/chart-bars.png" alt="A bar chart with eight ascending bars" caption="A chart, contained. The axes survive the narrow frame." role="illustration" loading="lazy" >}}

---

{{< interactive/cta title="See how to write your own." subtitle="Images, figures and the pipeline, in the docs." buttonText="Image docs" buttonUrl="/docs/images/" >}}

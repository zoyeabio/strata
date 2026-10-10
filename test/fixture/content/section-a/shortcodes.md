---
title: "Shortcode showcase"
date: 2026-01-06
weight: 60
---

Every theme shortcode rendered in one page; scripts/smoke.sh asserts the
output contract.

## figure

{{< figure src="photo-flat.png" caption="A flat photo" >}}

{{< figure src="inline.png" alt="Inline illustration" title="With a title" width="400" height="300" link="/section-a/flat/" target="_blank" rel="noopener" class="extra" >}}

{{< figure src="photo-flat.png" alt="Quality override" caption="q60" quality="60" >}}

## content

{{< content/article link="/section-a/flat/" showSummary=true >}}

{{< content/list limit=2 cardView=true title="Grid picks" >}}

{{< content/list limit=2 cardView=false title="Row picks" >}}

{{< content/icon "check" >}}

## interactive

{{< interactive/email user="info" domain="example.com" >}}

{{< interactive/cta icon="check" title="Try the form below" subtitle="No backend in the fixture" buttonText="Go" buttonUrl="/contact/" >}}

{{< interactive/contact >}}

{{< interactive/carousel images="images/section-a/*.png" captions="{inline.png: Inline image, photo-flat.png: Flat photo}" aspectRatio="16-9" interval="1500" >}}

## layout

{{< layout/multi-col columns="2" ratio="2:1" gap="2rem" align="top" >}}
{{< layout/col-left >}}
### Left column

Markdown inside the first column.
{{< /layout/col-left >}}
{{< layout/col-right >}}
### Right column

Markdown inside the last column.
{{< /layout/col-right >}}
{{< /layout/multi-col >}}

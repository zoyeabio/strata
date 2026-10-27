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

{{< figure src="photo-flat.png" alt="Card role" caption="Card-sized variants" role="card" >}}

## content

{{< content/article link="/section-a/flat/" showSummary=true >}}

{{< content/list limit=2 cardView=true title="Grid picks" >}}

{{< content/list limit=2 cardView=false title="Row picks" >}}

{{< content/list limit=1 cardView=false summary=false title="Row picks, no summary" >}}

{{< content/icon "check" >}}

## interactive

{{< interactive/faq "Is FAQ schema valid?" >}}
Yes, it emits both Microdata and aggregated FAQPage JSON-LD.
{{< /interactive/faq >}}

{{< interactive/email user="info" domain="example.com" >}}

{{< interactive/cta icon="check" title="Try the form below" subtitle="No backend in the fixture" buttonText="Go" buttonUrl="/contact/" >}}

{{< interactive/contact >}}

{{< interactive/carousel images="images/section-a/*.png" captions="{inline.png: Inline image, photo-flat.png: Flat photo}" alts="{inline.png: A person working at a desk}" aspectRatio="16-9" interval="1500" >}}

{{< interactive/carousel images="images/section-a/inline.png" fit="contain" aspectRatio="4-3" interval="3000" >}}

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

## Ads

{{< ads slot="1234567890" >}}

## map

{{< map src="https://maps.google.com/maps?q=Shanghai&z=13&output=embed" title="Shanghai office map" >}}

---
title: "Documentation"
description: "User-facing documentation for the Strata Hugo theme. Everything here describes shipped behaviour."
keywords: ["documentation", "reference", "theme"]
featureimage: "images/hero-docs.png"
featureimagealt: "A pale field darkening toward the horizon"
showsummary: false
---

Everything in this section describes shipped behaviour. If something is
not here, it is not part of the contract.

## Start here

| Document | Contents |
|---|---|
| [Installation](/docs/installation/) | Module setup, the taxonomy contract, first build |
| [Configuration](/docs/configuration/) | Site params, front matter keys, site hooks |
| [Images](/docs/images/) | Storage rules, resolution order, ladder, roles |
| [Typography](/docs/typography/) | Type scale, prose width, system font stack |
| [Customization](/docs/customization/) | Colour schemes, CSS variables, custom CSS |
| [Shortcodes](/docs/shortcodes/) | Shortcode reference and supported parameters |
| [Sitemap](/docs/sitemap/) | The sitemap, `robots.txt`, what gets listed |
| [Security](/docs/security/) | Response headers, the strict CSP, Cloudflare limits |
| [Troubleshooting](/docs/troubleshooting/) | Hugo platform behaviours that look like theme bugs |

## The short version

- Hugo **0.161.0 or later**, Extended edition. Node 22 or later.
- Add the module, allow `node` and `tailwindcss` in `security.exec`, and
  build. That is the whole installation.
- Declare `mainSections` so the theme knows which of your sections are
  articles and which are pages.
- Put images in `assets/images/` and reference them as
  `images/name.png`. The pipeline does the rest.
- Anything the theme does not document, you do not need to configure.

## Reading it in order

Installation is the only page you need to read twice. Configuration is
the page to keep open while you are building, because it is the contract
for what a site owns. Images and typography are the two pages that will
answer the question you actually have when something looks wrong.

---

{{< interactive/cta title="Not looking for the reference?" subtitle="See the shortcodes live, with examples." buttonText="Shortcode gallery" buttonUrl="/shortcodes/" >}}

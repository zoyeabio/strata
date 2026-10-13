---
title: "Security"
description: "The response headers the theme ships, the strict Content-Security-Policy, and which Cloudflare limits actually bind."
keywords: ["security", "csp", "headers", "cloudflare", "hosting"]
weight: 80
---

## Headers

The theme ships `static/_headers`, which Hugo copies to the output root. Cloudflare Pages and Netlify both read it, so security is a default rather than a step you remember to add.

A site with its own `static/_headers` wins over the theme's — that is the supported way to relax one directive without forking the theme, since Hugo gives the site's static directory precedence.

Five headers: `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, a `Permissions-Policy` that denies camera, microphone, geolocation, payment, USB and the interest cohort, and a `Content-Security-Policy`.

The policy is strict: `default-src 'self'` with `script-src 'self'` and no `unsafe-inline`, `object-src 'none'`, `frame-ancestors 'none'`, `base-uri 'self'` and `form-action 'self'`.

That is only achievable because of how the theme is built:

- every script and stylesheet ships from the origin and carries an SRI `integrity` attribute
- `js/carousel.js` and `js/contact.js` are external assets, not inline. Their shortcodes used to interpolate the instance id and byte limit straight into the script; both now come from `data-*` attributes instead, so nothing is ever interpolated into JavaScript
- the JSON-LD blocks look like inline scripts but carry a non-executable type and are exempt from `script-src`

## Documented relaxations

Each is called out in `_headers` with the exact change to make.

**`style-src 'unsafe-inline'`** — the carousel writes a dynamic `aspect-ratio: W / H` attribute that has no class equivalent. Inline style cannot execute code, so this is a much smaller opening than an inline script. Removing it needs a nonce, and Hugo does not generate nonces.

**`frame-src` google origins** — the `map` shortcode is the theme's explicit opt-in to a third-party embed, and its documented example is a Google Maps URL. Add your provider's origin rather than widening to `https:`.

**Ads** — `site.Params.ads.client` turns on the AdSense loader, which needs `pagead2.googlesyndication.com` and the doubleclick.net origins in `script-src`, `connect-src`, `img-src` and `frame-src`, plus `unsafe-inline` in `script-src` per Google's current recommendation. Its `(adsbygoogle = window.adsbygoogle || []).push({})` call is the one executable inline script the theme emits, and it only lands on pages that use the `ads` shortcode. Enabling ads is a deliberate relaxation of the default policy.

**`frame-ancestors 'none'`** — delete it if you want the site embeddable in an iframe.

## Cloudflare Pages limits

The ones that bind for a content site. Verified against the Pages and Workers limits pages.

| Limit | Free | Why it matters |
|---|---|---|
| Files per site | 20,000 | The real ceiling. Paid is 100,000 with `PAGES_WRANGLER_MAJOR_VERSION=4`. |
| Single file | 25 MiB | Rarely reached. |
| Builds | 500/month, 1 concurrent, 20 min timeout | This is the one that hurts: posting several times a day exhausts it. |
| `_headers` rules | 100 rules, 2,000 chars per header | The theme uses one rule block. |
| `_redirects` | 2,000 static + 100 dynamic | Only matters when rewriting slugs at scale. |
| Total size, bandwidth, requests | No documented limit | Static assets are not billed and do not count against anything. |

Two notes on the file count. It scales with source images times the distinct **roles** each image is used at, never with the number of times an image appears — the same role reuses the same fingerprinted files. And Workers' 100,000 requests/day free cap applies only to **Pages Functions**; purely static requests do not count. Adding `/api/contact` as a Pages Function starts those requests counting.

The image pipeline is what keeps the number low: one WebP quality across all widths so a width is never stored twice, at most four variants per role, and a social preview only where a page declares one.

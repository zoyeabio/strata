---
title: "SEO and GEO"
description: "What Strata emits for search engines and generative engines, and the steps to take before you go live."
keywords: ["seo", "geo", "structured data", "sitemap", "robots", "json-ld"]
weight: 55
---

Strata is built to be found. This page lists what the theme emits on your
behalf, what to verify before launch, and the one production setting the
example site deliberately gets wrong so it is never indexed as `example.com`.

## What the theme emits

- **Structured data (JSON-LD):** `Organization`, `WebSite`, `WebPage`, and
  `BreadcrumbList` on every page; `Article` on articles — carrying `author`
  (a `Person`), `datePublished`, `dateModified`, `headline`, `image`,
  `keywords`, and `publisher` (an `Organization`); and `FAQPage` wherever you
  use `interactive/faq`.
- **Crawl signals:** a `canonical` link, a `meta description`, and Open Graph
  plus Twitter cards on every page.
- **Discovery:** a `sitemap.xml` covering all public URLs (referenced from
  `robots.txt`) and an RSS feed at `index.xml`.
- **Performance:** responsive image ladders (WebP + `srcset`) keep Core Web
  Vitals healthy, which search ranking rewards.
- **Machine-readable structure:** semantic headings, a per-page table of
  contents, and accessible `<details>` FAQ blocks — all of which help language
  models parse and cite the content.

## Before you go live

1. Set the real `baseURL` in your site config. The example uses
   `https://example.com/`.
2. **Replace the demo `robots.txt`.** The example site ships `Disallow: /`
   so engines never crawl it; your production site must allow crawling (see
   the template below).
3. Submit your `sitemap.xml` to Google Search Console and Bing Webmaster
   Tools.
4. Give every public page a real `featureimage` so the share/OG card resolves
   to a 1200×630 image.
5. Keep `dateModified` / `lastmod` accurate. Fresh, dated content is what both
   search and generative engines weight most.

## Production robots.txt

```
User-agent: *
Allow: /

Sitemap: https://your-domain.example/sitemap.xml
```

Save it as `static/robots.txt` in **your site**, not in the theme. The theme
does not ship one, so the file you provide wins.

## GEO notes

Structured, dated, attributed, and entity-clear content is easier for search
and retrieval systems to interpret. Strata's schema supplies the author,
publisher, dates, article section, and word count. These signals improve
machine-readable completeness; they do not guarantee ranking, inclusion, or a
citation. Two useful content practices are:

- Add an `interactive/faq` block when the page genuinely answers recurring
  questions; it exposes the same visible answers as structured FAQ data.
- Keep a table of contents on long articles so readers and machines can see
  section boundaries explicitly.

Neither requires a plugin; both are plain content.

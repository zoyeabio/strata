---
title: "Troubleshooting"
description: "The Hugo platform behaviours that look like theme bugs, and how to work around them without editing the theme."
keywords: ["troubleshooting", "hugo", "gotchas", "debug"]
weight: 90
---

Everything here is Hugo behaviour, not a Strata bug. These are the traps
that look like theme defects because they only surface when a site crosses
into a Hugo edge case. Fixing them means one line of site config or one
line of front matter, never a template edit.

## A page with a future `date` never renders

Hugo drops any page whose `date` is after the current wall clock. The
page is silently absent from the list, the search index and the sitemap.
There is no error, no warning, no log line. It simply is not there.

To include future-dated pages in the current build, set one of:

```toml
# config/_default/hugo.toml
buildFuture = true
```

or pass `--buildFuture` on the command line. Turn it off before a
release: publishing an article dated next month as live today is a
contradiction that lands in the JSON-LD `datePublished` field, where a
search engine may read it as fabricated history.

## Menu items disappear after a page rename

Menus point at pages through `pageRef`, not at URLs. When you rename a
page, the reference becomes stale and the item silently stops rendering.
Use `pageRef` rather than a bare `url`:

```toml
[[main]]
  name = "Journal"
  pageRef = "posts"
  weight = 1
```

`pageRef` also survives content moves, because Hugo resolves it by
page path at build time. A `url = "/posts/"` breaks the same way on a
move, and it does not go through Hugo's rewrite rules.

## A custom `layout` misses related articles and pagination

Hugo's default `single.html` ends by calling `partials/page/related.html`
and `partials/page/pagination.html`. A custom layout that replaces it
does not automatically pick those up — you have to include them. The
theme ships `related` and `pagination` behind site params, so a
custom layout without the calls loses both features silently.

Copy the tail of `layouts/_default/single.html` if you write your own,
or extend `partials/extend-body.html` for a partial-only change.

## Markdown images wrap in `<p>` by default

A standalone image line in Markdown renders as `<p><img …></p>`, not a
bare `<img>`. Strata's `render-image.html` hook handles the `srcset`
and `sizes` pipeline regardless, but any CSS that assumes an image sits
directly in the flow (margin collapse, centred) has to look through
the paragraph. Two options:

- Leave it. Prose reads more naturally with the paragraph break, and
  this is what Hugo and GitHub both do.
- Set `wrapStandAloneImageWithinParagraph = false` under
  `[markup.goldmark.parser]` if your CSS wants images to be their own
  block.

The pipeline runs either way; this only affects the surrounding `<p>`.

## Shortcodes that return HTML

Strata shortcodes render elements directly. If you write your own and
forget to call `.Inner | safeHTML` on nested content, Hugo escapes it
and any nested shortcode renders as literal text. If you do use
`safeHTML`, remember the content is trusted — it is a raw HTML
pass-through, not a sanitiser.

## `where` inside `content/list` matches a page field, not a section name

The shortcode passes `where` and `value` straight to Hugo's `where`
filter over `site.RegularPages`. The field name must be a page
property. `Type` and `Section` both work for a top-level section:

```
{{< content/list where="Type" value="posts" limit="5" >}}
```

A typoed field name matches nothing — the filter runs against an empty
set of matches and returns the whole unfiltered list. Strata cannot
warn about this: any page property is a valid filter, and a site with
custom front matter may legitimately filter on it. Read the shortcode
output when a `where` clause returns more pages than expected.

## Deprecated `languageCode` and `languageName` keys

Hugo 0.158 deprecated `languages.<lang>.languageCode` and
`languageName` in favour of `locale` and `label`. Both still work, but
they warn on every build. The theme's own `languages.en.toml` has
already been renamed; a scaffolded site needs the same change in its
own `config/_default/languages.en.toml`:

```toml
[en]
  locale = "en"
  label = "English"
```

The value stays `"en"` rather than `"en-US"`: the templates read
`site.Language.Locale` into `<html lang>`, `og:locale` and the
`content-language` meta, so a richer locale would change all three.

## Hugo Module path is not interchangeable with site URL

`module.imports.path` takes a Go module path — `github.com/zoyeabio/strata`.
A site's own `module` line is a separate thing that names the site's
documentation URL. Both are required; the scaffold writes
`module example.com/<slug>` for the site, which is Go's reserved
documentation domain and is never fetched.

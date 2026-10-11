# Sitemap

The theme ships Hugo's built-in `sitemap.xml`, which lists every page that has
any rendered output — including `/tags/` taxonomy indexes and every `/tags/x/`
term page. `robots.txt` is emitted with a `Sitemap:` line when the site sets
`enableRobotsTXT = true`.

For a trade or reference site those term pages are noise: crawlers get told
they should index `/tags/gut-health/`. Hugo gives you no per-kind switch, so
this is the one place the theme will not cover you.

## What does not work

```toml
[outputs]
  taxonomy = ["HTML"]
  term = ["HTML"]
```

This drops the term RSS feeds but leaves every HTML term page in the sitemap.
Verified on this checkout: 19 `<loc>` entries before and after, 8 of them
taxonomy/term both times. Restricting a kind's output list removes the extra
formats, not the page. There is also no `disablesInSitemap` format option in
Hugo 0.151.0 — grepping the module source for it returns nothing.

## What works: a site-layer template

Add `layouts/_default/sitemap.xml` to the host site. It is Hugo's built-in
with a kind filter on the `range` — keep the `Sitemap.Disable` filter, which
is the built-in's own per-page opt-out:

```html
{{ printf "<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"yes\"?>" | safeHTML }}
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
  {{ range where .Pages "Sitemap.Disable" "ne" true }}
    {{- if and .Permalink (ne .Kind "taxonomy") (ne .Kind "term") }}
  <url>
    <loc>{{ .Permalink }}</loc>{{ if not .Lastmod.IsZero }}
    <lastmod>{{ safeHTML (.Lastmod.Format "2006-01-02T15:04:05-07:00") }}</lastmod>{{ end }}{{ with .Sitemap.ChangeFreq }}
    <changefreq>{{ . }}</changefreq>{{ end }}{{ if ge .Sitemap.Priority 0.0 }}
    <priority>{{ .Sitemap.Priority }}</priority>{{ end }}
  </url>
    {{- end -}}
  {{ end }}
</urlset>
```

Verified against `test/fixture`: 19 entries down to 13, and zero `/tags/` or
`/series/` locs. Page kinds are `home`, `page`, `section`, `taxonomy`, `term`;
a term's RSS output is kind `RSS` and shares the term's URL, so filtering the
two kinds above is what removes the duplicates.

The template is a site-layer file on purpose: the theme stays on Hugo's
default, which is the right answer when term pages are meant to be indexed.
The same override is also where a custom index belongs — dropping an RSS feed
or external URL out of the sitemap does not need a different mechanism.

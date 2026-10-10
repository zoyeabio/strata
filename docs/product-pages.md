# Product pages (planned)

Product and ingredient pages are a **site-layer** concern, not part of the
theme. The split:

- **Theme** ships reusable spec blocks (a definition-list spec table,
  certification badges) as partials a site can call, plus the
  `schema.enableProduct` switch that turns on Product JSON-LD once a site
  provides the product template.
- **Site** owns the product layout, taxonomy and copy. The product page
  template lives in the site's `layouts/`, because the data model differs
  per business (ingredient vs. finished product vs. strain).

Status: not shipped. `schema.enableProduct = true` is accepted but has no
effect until a site-layer product template exists.

When the partials land, this page will document:

- the spec-table and cert-badge partial inputs
- front matter shape for product pages
- the Product JSON-LD contract

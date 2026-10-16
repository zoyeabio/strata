# Contributing

## Ground rules

- **No implicit external requests** at build time or runtime — no CDNs,
  webfonts or analytics. Only documented map, AdSense and site-hook opt-ins
  may add third-party requests.
- **No placeholder or site-specific content** in the theme: no brand names,
  no sample marketing copy, no dead links.
- **Configuration is externalised**: nothing site-shaped is hard-coded in
  templates; it comes from params, front matter or data files.
- **Comments**: file headers document purpose, inputs and callers. No
  inline comments in code or CSS.

## Development

```sh
npm install   # once — Hugo 0.161.0+ runs the Tailwind CSS CLI through node
```

CSS compiles in-process on every build; there is no committed bundle to
regenerate.

## Before you push

```sh
./scripts/smoke.sh                    # fixture contract assertions
./scripts/validate-theme.sh           # production build, output rules, example coverage
./scripts/validate-example.sh         # exampleSite demonstrates the theme; also run by validate-theme.sh
./scripts/validate-site.sh /path/site # your site against this checkout
./scripts/audit-partials.sh layouts   # orphan / missing partials
```

All five must pass. New behaviour means a new assertion, not a comment.

## exampleSite is a second test suite

`test/fixture` asserts mechanically: a fixture page, a config overlay, a smoke
assertion. exampleSite is the other half, the demo a reader opens. It carries
a live example of every shortcode and a working implementation of every site
hook, so a shortcode stays documented and a hook stays copyable.
`scripts/validate-example.sh` keeps that coverage honest: a shortcode or a hook
that ships without a live example fails the gate.

`exampleSite/layouts/partials/` is the reference implementation of the site
hooks in docs/configuration.md, and `exampleSite/assets/css/example.css` is the
reference `customCSS` file. Both are consumed only by markup the example emits
itself, which is the intended use rather than an accident of the demo.

## Templates

- Partials: `data/` returns values via `return` (strings, slices or dicts —
  never HTML), `media/` emits elements,
  `page/` composes blocks, `frame/` is the page shell, `head/` is `<head>`.
- Every partial header lists purpose, parameters and callers.
- Site hooks use `templates.Exists` so a site can extend without forking.

## CSS

- Source lives in `assets/css/base/` and `assets/css/components/`; schemes
  in `assets/css/schemes/`. Every file carries its own `@layer` wrapper and
  the concatenation order lives in `layouts/partials/head/head.html`.
- Cascade layers are registered in `main.css`; do not add `!important`.
- New class tokens must be covered by the class-coverage assertion in
  `scripts/smoke.sh`.

## Commits

- One concern per commit; message in English, imperative mood.
- Every template or CSS change ships with its assertion in the same commit.
- Run the validators against a real site before merging anything that
  touches rendering paths.

# Contributing

## Ground rules

- **No external requests** at build time or runtime — no CDNs, webfonts,
  analytics or third-party scripts.
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
./scripts/validate-theme.sh           # production fixture build + output rules
./scripts/validate-site.sh /path/site # your site against this checkout
./scripts/audit-partials.sh layouts   # orphan / missing partials
```

All four must pass. New behaviour means a new assertion, not a comment.

## Templates

- Partials: `data/` returns dicts (no HTML), `media/` emits elements,
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

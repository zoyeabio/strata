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
npm install            # once
npm run build:css      # regenerate assets/css/compiled/main.css
```

Never hand-edit `assets/css/compiled/main.css` — it is generated, and the
smoke test fails when it is stale.

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

- Source lives in `assets/css/{base,components,utilities}/`; schemes in
  `assets/css/schemes/`.
- Cascade layers are registered in `main.css`; do not add `!important`.
- New class tokens must be covered by the class-coverage assertion in
  `scripts/smoke.sh`.

## Commits

- One concern per commit; message in English, imperative mood.
- Every template or CSS change ships with its assertion in the same commit.
- Run the validators against a real site before merging anything that
  touches rendering paths.

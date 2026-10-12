# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Strata was rebuilt from scratch as a standalone Hugo module, file by file,
against zoyclaw v1.3.0 as the visual reference. Every step was a production
build plus a browser-verified pass at 1440 / 1280 / 390. The per-step log is
gone — what survives here is the set of decisions that would otherwise have to
be re-derived from the templates.

### Deliberate choices

- **No external requests**, build time or runtime: no CDNs, webfonts,
  analytics or third-party scripts. The reference theme shipped Google Fonts;
  Strata uses system stacks. No gate asserts this — it is a standing rule, not
  a check.
- **Config is data, not code.** The variant ladder, role caps, WebP quality,
  social preview size, the page image budget and the per-role minimum source
  width live in the theme's root `config.toml` under `[params.image]` and
  `[params.build]`, read by the templates with the previous hardcoded values as
  fallbacks. `scripts/lib/build_config.py` resolves the same file pair for the
  build scripts, so a threshold changed in config is the threshold the gate
  checks. Hugo also merges a theme `config/_default/` and `config/production/`;
  the defaults ship from the root file only, so there is one place to look.
- **Reproducible builds.** Two independent builds of the same tree are
  byte-identical, so a swapping id or timestamp cannot slip past every content
  assertion. The carousel instance id is the ordinal alone — the wall-clock
  suffix it once carried made every rebuild a diff.
- **The prose measure is for prose.** Article bodies get a 720px column;
  sections, terms and the home page ride the full content column, so a landing
  page never leaves dead air at the right edge.

### Behaviour notes

- **One image resolver.** `data/image-ref.html` serves cards, term cards,
  heroes and social output. Cards and heroes take `featureimage`, else a page
  bundle resource whose name contains `feature`, `cover` or `thumbnail`, so a
  page bundle with a sibling `featured.jpg` needs no front matter key. Social
  falls back to `images[0]`, then `site.Params.defaultSocialImage`, and
  `featureimage` still beats `images` — the picture a page shows is the picture
  it advertises.
- **The taxonomy contract is enforced at validation, not declared.** Hugo does
  not inherit a theme's `[taxonomies]`, so a theme `hugo.toml` declaring them
  would be read by nobody. `validate-site.sh` asserts the host site declares
  `tags` and `series`; tag and series links resolve through `GetTerms`, so a
  tag with no built term page renders no link instead of a dead one.
- **The hero preload goes through `safeHTML`.** html/template URL-escapes the
  `imagesrcset` attribute, so a bare expression turned `url 480w` into one
  malformed URL and silently killed the preload.
- **Summary truncation is CSS, not template.** The card emits the whole
  plainified summary; a 3-line clamp plus a `calc(3lh)` hard cap does the cut.
  Chromium without legacy `-webkit-box` computes even inline
  `display: -webkit-box` as `flow-root`, so `line-clamp` alone limits height
  without paint-clipping and a fourth line bled to the card edge.

### Gates

`smoke.sh` (fixture assertions, rebuilt and re-verified on every run),
`check-build.sh` (R1–R15), `validate-theme.sh`, `validate-site.sh`,
`audit-partials.sh` (missing/orphan partial call graph), `new-site.sh` and
`place-image.sh`. A behaviour change ships with its assertion; the standing
rules live in `CONTRIBUTING.md`.

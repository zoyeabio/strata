#!/usr/bin/env python3
"""Resolve strata's build config and print shell assignments.

The theme's defaults live in config/_default/*.toml and a site overrides them
in its own config. Hugo merges those same files when it renders, so the build
scripts and the templates judge one source of truth instead of two copies of
the same number. The theme's config/_default/ is read here in the same order
Hugo reads it: sorted by name, lowest precedence first.

Site files are read in Hugo's precedence order, lowest first: config/_default/,
config/<environment>/, files in config/, then config.toml at the site root. The
environment defaults to production, which is Hugo's own default; pass
--environment to match a build made for a different one.

Usage:
  eval "$(python3 scripts/lib/build_config.py [--site /path/to/site] [--environment production])"
"""
import argparse
import tomllib
from pathlib import Path

THEME = Path(__file__).resolve().parents[2]
# Hugo's own default environment. Pass --environment to match a build made for
# a different one: Hugo then skips config/production/ and so do these scripts.
ENV = 'production'

# name -> (default, path under [params])
KEYS = {
    'IMAGE_LADDER': ([480, 800, 1280, 1920], ('image', 'ladder')),
    'IMAGE_QUALITY': (78, ('image', 'quality')),
    'IMAGE_CAP_CARD': (800, ('image', 'caps', 'card')),
    'IMAGE_CAP_ILLUSTRATION': (1280, ('image', 'caps', 'illustration')),
    'IMAGE_CAP_HERO': (1920, ('image', 'caps', 'hero')),
    'IMAGE_CAP_OG': (1920, ('image', 'caps', 'og')),
    'OG_WIDTH': (1200, ('image', 'og', 'width')),
    'OG_HEIGHT': (630, ('image', 'og', 'height')),
    'PAGE_IMAGES_KB': (600, ('build', 'pageimageskb')),
    'MIN_WIDTH_HERO': (1600, ('build', 'minwidth', 'hero')),
    'MIN_WIDTH_ILLUSTRATION': (1280, ('build', 'minwidth', 'illustration')),
    'MIN_WIDTH_CARD': (1200, ('build', 'minwidth', 'card')),
    'MIN_WIDTH_OG': (1200, ('build', 'minwidth', 'og')),
}


def _merge(base, override):
    out = dict(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            out[key] = _merge(out[key], value)
        else:
            out[key] = value
    return out


def _toml_files(root, environment=ENV):
    """The site's TOML config, lowest precedence first."""
    files = []
    for level in (('_default',), (environment,), ()):
        directory = root.joinpath(*(('config',) + level))
        if directory.is_dir():
            files.extend(sorted(directory.glob('*.toml')))
    return files + sorted(root.glob('config*.toml'))


def _load(path):
    try:
        return tomllib.loads(path.read_text(encoding='utf-8'))
    except (tomllib.TOMLDecodeError, OSError):
        return {}


def _get(mapping, path):
    node = mapping
    for key in path:
        if not isinstance(node, dict) or key not in node:
            return None
        node = node[key]
    return node


def load(site=None, environment=ENV):
    cfg = {}
    for theme_cfg in sorted((THEME / 'config' / '_default').glob('*.toml')):
        cfg = _merge(cfg, _load(theme_cfg))
    if site:
        for path in _toml_files(Path(site), environment):
            cfg = _merge(cfg, _load(path))
    params = cfg.get('params', {})
    out = {}
    for name, (default, path) in KEYS.items():
        value = _get(params, path)
        if value is None:
            out[name] = default
        elif isinstance(default, list):
            out[name] = [int(v) for v in value]
        else:
            out[name] = int(value)
    return out


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--site')
    parser.add_argument('--environment', default=ENV)
    args = parser.parse_args()
    for name, value in load(args.site, args.environment).items():
        if isinstance(value, list):
            value = ' '.join(str(v) for v in value)
        # Single-quoted so a list like 480 800 1280 1920 evals as one value.
        print(f"{name}='{value}'")

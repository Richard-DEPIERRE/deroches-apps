# Site kit

Every app's website, built from Markdown into static files and served by Cloudflare (Workers static assets).
French lives at the root and English under `/en/`; the two versions of a page are linked as translations of each other.
The sites set no cookies, load nothing from another origin and have no forms: no cookie banner, no personal data.

## Layout

```
sites/
  kit/              the builder (Node, no framework) and its tests
    build.mjs       node kit/build.mjs <site dir> [out dir]
    lib/            config, content, render, seo, i18n
    assets/         the shared stylesheet (fingerprinted on build)
    test/fixture/   a test site, also the reference for a new site
  legal/            Richard's legal-identity file, included by the legal notice (not written by agents)
  <slug>/           one folder per app, named after its slug
    site.json
    content/fr/     French pages (served at /)
    content/en/     English pages (served at /en/)
```

## site.json

| Field | Meaning |
|---|---|
| `slug` | the app's slug, as in its `App:` issue and the allow-lists |
| `domain` | the bare domain, e.g. `example.fr` (canonical URLs, sitemap and robots use `https://<domain>`) |
| `status` | `coming-soon` until the app is on a store, then `live` (a live site needs at least one store URL) |
| `name.fr`, `name.en` | the app's name in each language |
| `stores.ios`, `stores.android` | store URLs, or `null` until the app is on that store |
| `themeColor` | optional, `#rrggbb` |
| `category` | optional schema.org application category (default `UtilitiesApplication`) |

## Pages

One Markdown file per page. The file path is the URL: `content/fr/guides/frais-reels.md` is `/guides/frais-reels/`,
`content/en/guides/actual-costs.md` is `/en/guides/actual-costs/`, and `index.md` is its folder's page. File and folder
names are slugs (lowercase letters, digits, hyphens). Each language needs its `index.md`.

```yaml
---
title: Frais réels ou abattement de 10 % ?    # required; <title> and H1 wording (about 50–60 characters)
description: Comment comparer les deux…        # required; meta description (about 120–160 characters)
translation: actual-costs                      # same key on the French and the English page = translations
type: guide                                    # home | page | guide | legal (default: page; index.md is home)
updated: 2026-11-01                            # last real change; the sitemap's lastmod
noindex: true                                  # optional; kept out of search and the sitemap
---
```

The build fails on a missing title or description, a file name that isn't a slug, a duplicate URL, a translation key
used twice in one language, or a missing home page.

## What the build writes

- One `index.html` per page: `lang`, canonical URL, `hreflang` alternates (plus `x-default`, the French page) when a
  translation exists, Open Graph tags, a language switch (to the translation, else to the other home page).
- Structured data (JSON-LD): `WebSite` on home pages; `MobileApplication` with its store links once the site is `live`.
  Never a rating or a review we don't have.
- `sitemap.xml` with `lastmod` and the French and English alternates of each page; `robots.txt` pointing to it.
- `404.html` and `en/404.html`; `_headers` with a strict Content-Security-Policy (no other origin, no forms).

## Commands

Run from `sites/`:

```
npm ci
npm run lint                       # Biome
npm test                           # node --test
npm run build -- <slug>            # writes <slug>/dist/
```

## Still to come (child issues of DAPP-6)

The guide template with download buttons and app banners, internal links and the link check; the legal notice,
privacy policy, terms and the coming-soon page; the cookie-free analytics that count store clicks, and the deploy
config; the daily-guide pipeline (one new guide per app per day, only after `CE-FACT-CHECK`).

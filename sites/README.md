# Site kit

Every app's website, built from Markdown into static files and served by Cloudflare (Workers static assets).
French lives at the root and English under `/en/`; the two versions of a page are linked as translations of each other.
The sites set no cookies, load nothing from another origin and have no forms: no cookie banner, no personal data.

## Layout

```
sites/
  kit/              the builder (Node, no framework) and its tests
    build.mjs       node kit/build.mjs <site dir> [out dir]
    wrangler.mjs    node kit/wrangler.mjs <site dir>: writes the site's wrangler.jsonc from the template
    lib/            config, content, render, seo, i18n
    worker/         the Worker in front of every site: store-click redirects and the analytics beacon
    assets/         the shared stylesheet and the analytics script (fingerprinted on build)
    templates/      the legal pages and wrangler.jsonc
    test/fixture/   a test site, also the reference for a new site
  legal/            Richard's legal-identity file, included by the legal notice (not written by agents)
  <slug>/           one folder per app, named after its slug
    site.json
    wrangler.jsonc  the deploy config, from the kit template (never edited by hand)
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
| `supportEmail` | the app's support address: contact on the support page, and privacy-rights contact on the legal pages |
| `replyWithinWorkingDay` | optional, `true` only once Support confirms it keeps that promise: the support page then says every email gets an answer within a working day. Absent or `false`: no promise |
| `appData.fr`, `appData.en` | Markdown: what the app collects, the privacy policy's app section. It must match the store privacy answers (App Privacy, data safety) once they exist |
| `stores.ios`, `stores.android` | store URLs, or `null` until the app is on that store |
| `accent.light`, `accent.dark` | required, `#rrggbb`: the app's own link, focus and browser-bar colour in each scheme. The build refuses one under 4.5:1 against the page (`#ffffff` light, `#111113` dark) and adds it to the site's own hashed stylesheet. No shared studio colour. |
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

## Legal pages

The kit writes the three legal pages of every site in both languages from `kit/templates/legal/` (paired as
translations, linked from every footer): the legal notice (`/mentions-legales/`, `/en/legal-notice/`), the privacy
policy (`/confidentialite/`, `/en/privacy/`) and the terms (`/conditions/`, `/en/terms/`). A site overrides one with
its own `content/<lang>/<same path>.md` (`type: legal` and the same `translation` key: `legal-notice`, `privacy`,
`terms`). Placeholders: `{{name}}`, `{{domain}}`, `{{support}}`, `{{updated}}` (the page's `updated`), `{{appData}}`
and `{{identity}}`, each alone on its line for the last two.

The legal notice always carries Richard's `legal/identity.json` (appended when an override leaves `{{identity}}`
out). `--production`, the deploy build, fails when that file is missing or a required field is empty. A review build
without it shows a visible "identity file missing" box and keeps the legal notice `noindex`.

## Support page

The kit also writes every site's support page, the app's store **support URL**: `/aide/` and `/en/support/` (paired as
translations, key `support`, first in every footer), from `kit/templates/support/`. It says how to write to the
support address (a `mailto:` link, never a form), how to restore purchases (the app kit's Settings › Purchases), that
refunds go through Apple's or Google's refund pages, how to stop a subscription, and where the app's data lives (on the
phone, in the user's own iCloud or Google backup, and the kit's backup export). It matches what the app kit does; an
app that differs overrides the page with its own `content/<lang>/aide.md` or `support.md` (`type: page`,
`translation: support`). Placeholders: `{{name}}`, `{{support}}` (the address as an inline link), `{{updated}}`, and alone on
their line `{{contact}}` (the address as a full-size link of its own) and `{{reply}}` (the answer-time promise, empty
unless `replyWithinWorkingDay`). Menu paths keep a no-break space before each `›`, so no line starts with one.

## Coming-soon home page

While `status` is `coming-soon`, the home page is the site's own `index.md` (which must say, in at least one
paragraph, what the app will do), then "Bientôt sur l'App Store et Google Play" as plain text and links to the 10
newest guides. No store link, no form, no email capture, no countdown.

## What the build writes

- One `index.html` per page: `lang`, canonical URL, `hreflang` alternates (plus `x-default`, the French page) when a
  translation exists, Open Graph tags, a language switch (to the translation, else to the other home page).
- Structured data (JSON-LD): `WebSite` on home pages; `MobileApplication` with its store links once the site is `live`.
  Never a rating or a review we don't have.
- `sitemap.xml` with `lastmod` and the French and English alternates of each page; `robots.txt` pointing to it.
- `404.html` and `en/404.html`; `_headers` with a strict Content-Security-Policy (no other origin, no forms).
- `assets/a.<hash>.js`, the analytics script, on every page but the 404 pages.
- `_worker/index.mjs`, the Worker entry with the site's slug, store URLs and page paths embedded (kept out of the
  uploaded assets by `.assetsignore`).

## Analytics (ADR 0007)

No cookie, no identifier, nothing about the visitor. The Worker writes one data point per event to the Analytics
Engine dataset `site_events` (binding `EVENTS`), indexed by the site's slug:

| Column | Holds |
|---|---|
| `index1` | the site's slug |
| `blob1` | `page_view`, `store_click` or `read_depth` |
| `blob2` | the page path (`/guides/x/`), or empty when a click came from a page that isn't ours |
| `blob3` | `fr` or `en` |
| `blob4` | `ios` or `android` for a store click, else empty |
| `double1` | for `read_depth`: 25, 50, 75 or 100 (% of the page's main text reached; one event per step) |

- `GET /go/ios|android?from=<path>` counts a click and redirects (302) to the store URL in `site.json`; an unknown
  store, or one without a URL, goes to the home page.
- `POST /a` takes the script's beacon: `{"e":"view","p":<path>}` or `{"e":"depth","p":<path>,"d":25|50|75|100}`,
  at most 512 bytes, our own paths only, same origin only.
- Never add a `console.log` of a request, Workers Logs or Logpush: the privacy policy says we don't record IPs.

## Reading the numbers (Growth & Data)

The data is kept three months. Query it with the Analytics Engine SQL API: `POST` the query as the body to
`https://api.cloudflare.com/client/v4/accounts/<account id>/analytics_engine/sql` with
`Authorization: Bearer <token>`. Counts use `_sample_interval`, which is how many events a sampled row stands for.

The token: a Cloudflare API token with only **Account › Account Analytics › Read**, for Growth & Data. Growth & Data
asks Richard for it in a `needs-richard` issue: he creates it, saves it as the Paperclip secret
`CLOUDFLARE_ANALYTICS_TOKEN` and binds it to Growth & Data in `apps/agents.json`, with `api.cloudflare.com` in its
role's network list. The deploy token (`CLOUDFLARE_API_TOKEN`) is not for reading.

Views, store clicks and click rate per page per day (last 28 days):

```sql
SELECT toStartOfDay(timestamp) AS day, blob2 AS page,
  SUM(if(blob1 = 'page_view', _sample_interval, 0)) AS views,
  SUM(if(blob1 = 'store_click', _sample_interval, 0)) AS store_clicks,
  SUM(if(blob1 = 'store_click', _sample_interval, 0)) / SUM(if(blob1 = 'page_view', _sample_interval, 0)) AS click_rate
FROM site_events
WHERE index1 = '<slug>' AND blob1 IN ('page_view', 'store_click') AND timestamp > NOW() - INTERVAL '28' DAY
GROUP BY day, page
ORDER BY day DESC, views DESC
FORMAT JSON
```

Reading depth per guide (last 28 days): how many views reached each step (divide by `views` for the share).

```sql
SELECT blob2 AS guide,
  SUM(if(blob1 = 'page_view', _sample_interval, 0)) AS views,
  SUM(if(blob1 = 'read_depth' AND double1 = 25, _sample_interval, 0)) AS reached_25,
  SUM(if(blob1 = 'read_depth' AND double1 = 50, _sample_interval, 0)) AS reached_50,
  SUM(if(blob1 = 'read_depth' AND double1 = 75, _sample_interval, 0)) AS reached_75,
  SUM(if(blob1 = 'read_depth' AND double1 = 100, _sample_interval, 0)) AS reached_100
FROM site_events
WHERE index1 = '<slug>' AND blob2 LIKE '%/guides/%' AND timestamp > NOW() - INTERVAL '28' DAY
GROUP BY guide
ORDER BY views DESC
FORMAT JSON
```

Depth is a floor: a browser that never says the page was left sends none.

## Deploy and roll back

Each site deploys as the Worker `site-<slug>` on its domain, with `www.<domain>` redirecting to it (`site-<slug>-www`).
Deploy only what is merged on `main`, as one plain command run from the site's folder (change directory in a separate
command first; studio rules, section 1). Web & SEO and the Mobile Tech Lead deploy, with `CLOUDFLARE_API_TOKEN`.

1. A new site: run `node kit/wrangler.mjs <slug>` from `sites/` and commit the `wrangler.jsonc` it writes with the
   site, by PR. CI fails a `wrangler.jsonc` that differs from `kit/templates/wrangler.jsonc`; change the template,
   then rewrite every site's file, in one PR.
2. Check it builds and binds, from `sites/<slug>/`: `npx wrangler deploy --dry-run`.
3. Deploy, from `sites/<slug>/`: `npx wrangler deploy`. Its build is the production build, which stops without
   Richard's complete `legal/identity.json`. The domain must be on the Cloudflare account (Richard's per-app steps).
   Wrangler warns that no environment was named: the top-level one is the site, as intended.
4. Once per site, after the first deploy: `npx wrangler deploy --env www`.

Roll back, from `sites/<slug>/`: `npx wrangler versions list` shows the versions; `npx wrangler versions deploy
<version-id>` puts the last good one back. Or revert the change by PR and deploy again. `wrangler rollback` is
Richard's.

## Commands

Run from `sites/`:

```
npm ci
npm run lint                       # Biome
npm test                           # node --test
npm run build -- <slug>            # writes <slug>/dist/ for review
npm run build -- <slug> --production   # the deploy build: needs legal/identity.json
node kit/wrangler.mjs <slug>       # writes <slug>/wrangler.jsonc (--check compares it)
```

## Still to come (child issues of DAPP-6)

The store buttons (links to `/go/<store>?from=<page path>`, with their design review) and the guide template that places them, internal links and the link check; the daily-guide pipeline (one new guide per app per day, only after `CE-FACT-CHECK`).

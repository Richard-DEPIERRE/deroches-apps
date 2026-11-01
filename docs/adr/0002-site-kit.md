# ADR 0002: The site kit, static sites in French and English on Workers static assets

- Status: accepted
- Date: 2026-11-01
- Deciders: Web & SEO (review: Mobile Tech Lead, then Richard)
- Issue: DAPP-6

## Context

Every studio app has its own website. It goes live as soon as the domain exists, before the app ships, and publishes
one guide a day after `CE-FACT-CHECK` (studio rules, section 4). The sites exist to earn search traffic and send it to
the stores, in French first and English second. They collect no personal data: no cookie banner, no forms, a
"coming soon" page with no email capture, cookie-free analytics. Agents write the content every day, so the kit must
make the wrong thing hard to publish. Budget is $100 a month for everything, so hosting must stay inside free tiers.
ADR 0001 section 1 leaves the sites' stack to this ADR; apps and sites share nothing at build time.

## Decision

### 1. A small Node builder, no framework

- `sites/kit/build.mjs` turns each site's Markdown into static HTML: `node kit/build.mjs <site dir> [out dir]`, or
  `npm run build -- <slug>` from `sites/`, the only shape the README documents. Node 22 or later (`engines`).
- **Rejected: a static site generator** (Astro, Eleventy, Hugo). Each brings a templating language, plugins and a
  release cadence to keep current across many small sites, and none enforces our rules (hreflang pairs, no form, no
  other origin, the legal pages, one guide a day) without custom code anyway. The builder is about 400 lines we
  own and test; the rules live in it and fail the build.
- **Rejected: Flutter web** (poor for search, ADR 0001) and any server-side rendering (rules, anti-goal 1).

### 2. Dependencies, pinned exactly

| Package | Version | Why |
|---|---|---|
| `marked` | 18.1.2 | Markdown to HTML; small, no dependencies |
| `yaml` | 2.9.1 | front matter; YAML 1.2, no code execution |
| `@biomejs/biome` (dev) | 2.6.4 | lint and format in one tool, recommended rules |

Tests use Node's own `node:test`. Versions are exact in `package.json` and locked in `sites/package-lock.json`;
an upgrade is its own change.

### 3. Languages and URLs

- French at the root, English under `/en/`. A file's path is its URL (`content/fr/guides/x.md` is `/guides/x/`).
  File and folder names must be slugs.
- The two versions of a page share a `translation` key in their front matter. The build pairs them and writes
  reciprocal `hreflang` links, plus `x-default` pointing to the French page (France first). A page without a
  translation gets no alternates, and its language switch goes to the other language's home page.
- Every indexable page has its canonical URL, Open Graph tags and an entry in `sitemap.xml` with `lastmod` and its
  alternates. `noindex` pages get neither a canonical nor a sitemap entry.
- Structured data: `WebSite` on home pages; `MobileApplication` with the store links only once `site.json` says
  `live`. Never a rating or review we don't have.

### 4. Hosting: Cloudflare Workers static assets

- Each site deploys as a Worker with static assets (free tier), configured in its own `wrangler.jsonc` (DAPP-20), so
  a deploy is one plain `npx wrangler deploy` from the site's folder, from `main` only.
- `assets.not_found_handling: "404-page"` serves the nearest `404.html`, so the build writes `404.html` and
  `en/404.html`, one per language (Cloudflare docs, "Static site generation", read 2026-11-01).
- Response headers come from a `_headers` file the build writes (up to 100 rules, 2,000 characters a line; Cloudflare
  docs, "Headers", read 2026-11-01). `_headers` doesn't apply to responses the Worker's own code makes, so the
  store-click redirects (`/go/<store>`, DAPP-20) set the same headers in code.
- **Rejected: Cloudflare Pages.** Cloudflare's guide to moving from Pages to Workers says Workers has "a distinctly
  broader set of features" (read 2026-11-01), and the Worker is where the store-click counting runs anyway.

### 5. Content Security Policy

`default-src 'self'`, with `img-src 'self' data:`, `script-src`, `style-src` and `connect-src` all `'self'`,
`form-action 'none'`, `frame-ancestors 'none'` and `base-uri 'self'`; plus `nosniff`, a strict referrer policy and a
Permissions-Policy that turns off the camera, microphone and location. Nothing loads from another origin, so no
third-party script, font or tracker can be added by mistake, and no form can post anywhere. The stylesheet is
fingerprinted and cached for a year. The build already tests the fixture for other origins, cookies and forms;
DAPP-21 makes it refuse raw HTML forms, iframes, scripts and links to other origins in any Markdown, except the
`/go/<store>` links.

### 6. The legal identity is Richard's file

The legal notice of every site includes `sites/legal/identity.json`. Richard writes and merges it himself (studio
rules, section 1); agents never create, fill or copy it. `sites/legal/README.md` names its fields. Until it exists a
site can be built for review but not deployed (DAPP-19, DAPP-23).

### 7. Layout

```
sites/
  package.json, package-lock.json, biome.json
  kit/            the builder, its tests and the test fixture (the reference for a new site)
  legal/          Richard's identity file
  <slug>/         one site per app: site.json, content/fr/, content/en/; dist/ is built, never committed
```

The build empties its out dir first, so it refuses any out dir other than `<site>/dist` that is inside or around the
site or `sites/`.

## Consequences

- One kit for every site: a fix or a new rule reaches all sites on their next build. A site holds only its
  `site.json` and its Markdown.
- What the kit can't do (comments, search, newsletters, forms) the sites don't get. That is intended: no personal
  data.
- We maintain the builder ourselves. It stays small: a feature that needs a framework gets a new ADR.
- Lint, tests and a build of every site run in CI (DAPP-7), on the self-hosted runner.

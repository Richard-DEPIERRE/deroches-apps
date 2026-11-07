# ADR 0007: Cookie-free site analytics on Workers Analytics Engine, and one deploy config per site

- Status: proposed
- Date: 2026-11-06
- Deciders: Web & SEO (review: Mobile Tech Lead, then Richard)
- Issue: DAPP-20

## Context

The sites exist to send search traffic to the stores, so we need to count three things per page: views, store clicks
and how far people read (the `apps-daily-guide` skill places download buttons where readers stop). The privacy policy
(DAPP-19) promises no cookies, no identifier, and that we don't record the IP address Cloudflare receives. Budget is
$100 a month. A deploy must be one plain command (studio rules, section 1). Facts checked on 2026-11-06 in
Cloudflare's docs:

- Workers Analytics Engine on Workers Free: 100,000 data points written and 10,000 read queries a day, not billed yet
  ("Pricing", updated 2026-04-23). Data is kept three months ("Limits", updated 2026-04-23).
- Requests served from static assets are free and unlimited; requests that invoke the Worker count against the
  Workers plan, and on Free a matching `run_worker_first` request gets a 429 once the daily limit is used up
  ("Billing and Limitations", updated 2026-11-03).
- `_headers` doesn't apply to responses made by the Worker's code ("Headers").

## Decision

1. **A shared Worker in front of the static assets** (`sites/kit/worker/worker.mjs`). It runs only for `/go/*` and
   `/a` (`run_worker_first`), so pages and assets stay free and keep serving if the Worker quota runs out.
   - `/go/<store>?from=<path>` counts a store click (site, page path, language, store) and redirects (302) to the
     store URL from `site.json`. An unknown store, or one without a URL yet, goes to the home page.
   - `/a` takes a beacon from a 20-line first-party script (`/assets/a.<hash>.js`, `navigator.sendBeacon`): one page
     view per load, then one event per depth reached (25, 50, 75, 100 % of `<main>`) when the page is hidden or left.
     It accepts at most 512 bytes, JSON with only the known fields, one of the site's own page paths (embedded at
     build time), and refuses another `Origin`.
   - Nothing about the visitor is read into a data point: no IP address, user agent, referrer, identifier or cookie.
     No `console.log`, Workers Logs (`observability.enabled: false`) or Logpush.
   - Its own responses carry a strict CSP, `nosniff`, the referrer and permissions policies, and `no-store`.
   - `robots.txt` disallows `/go/` and `/a`, and the store links are `rel="nofollow"`, so crawlers don't count.
2. **One dataset for every site**, `site_events`, with the site's slug as the index (Analytics Engine samples per
   index, so a busy site never thins another's data). Columns: `blob1` event (`page_view`, `store_click`,
   `read_depth`), `blob2` page path, `blob3` language, `blob4` store, `double1` depth.
3. **`sites/<slug>/wrangler.jsonc` comes from `kit/templates/wrangler.jsonc`** (`node kit/wrangler.mjs <slug>`); CI
   fails a site whose file differs from the template. Its `build.command` runs the production build, so
   `npx wrangler deploy` from the site's folder is the whole deploy. `wrangler` is pinned (4.158.0) as a dev
   dependency of `sites/`.
4. **`www.` redirects with a second environment** of the same config (`site-<slug>-www`, `run_worker_first: true`),
   deployed once per site: every `www.` request reaches the Worker, which answers 301 to the bare domain. Only `www.`
   traffic counts against the Worker quota.
5. **The store buttons are not part of this change.** They link to `/go/<store>?from=<page path>` and come with the
   guide template (DAPP-21), which gets its own design review.

Rejected:
- **A third-party analytics service** (Plausible, Fathom, PostHog's web snippet): another origin in the CSP, a
  processor to name in the privacy policy, and a monthly cost.
- **Cloudflare Web Analytics**: its beacon loads from `static.cloudflareinsights.com` (another origin) and it counts
  neither store clicks nor reading depth.
- **`run_worker_first: true` on the main site**: every asset request would count against the Workers quota, and on
  Free the whole site would answer 429 past the limit.
- **A zone redirect rule for `www.`**: a dashboard step for Richard on each domain, outside the repo.

## Consequences

- Growth & Data reads views, store clicks, click rate and reading depth per page with the SQL API (queries in
  `sites/README.md`). That needs an Account Analytics Read token, which Growth & Data asks Richard for.
- Three months of history only: anything kept longer goes into Growth & Data's own reports.
- Up to five data points per page view: 100,000 a day covers about 20,000 views a day across all sites. Past that
  (or once Analytics Engine is billed), the cost goes through a `SPEND` check.
- The beacon and `/go/*` share the account's Workers Free quota (100,000 requests a day, every Worker on the account
  counted), and one page view can cost up to five Worker requests. Past the quota `/go/*` answers 429, so analytics
  traffic could break the store links. Growth & Data watches daily Worker requests and asks for Workers Paid (a
  `SPEND` check) before they reach about 50% of the quota.
- A reader whose browser never fires `pagehide` or `visibilitychange` sends no depth: depth rates are a floor.
- A store click from a page that no longer exists is counted with an empty path.

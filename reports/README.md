# reports: Richard's private report page

A read-only page that draws the research report and the Monday epics report as charts. It sits behind Cloudflare
Access and opens to Richard only. Each report has a **Decide in Paperclip** button that links to its approval.
Picks and validations are made on that approval and nowhere else: this page stores nothing. Design: ADR 0004
(`docs/adr/0004-private-report-page.md`).

Not an app site: never link to it from one, and keep it `noindex`.

## Layout
- `lib/markdown.mjs`: the small slice of Markdown the templates use (sections, tables, cards, cells).
- `lib/reports.mjs`: `parseResearchReport`, `parseEpicsReport`, `parseReport`. Each reads the template's
  sections into the data the pages draw. A `NOT ASSESSED` cell has `notAssessed: true` and `value: null`, never `0`.
- `lib/html.mjs`: escaping, the Markdown the cards use (bold, code, links, lists, nested tables), the page shell
  (`noindex`, a CSP that allows only the page's own style block, no script).
- `lib/render.mjs`: `renderResearchPage`, `renderEpicsPage`, `renderIndex`. Charts are inline SVG drawn at build
  time, coloured from the `dataviz` reference palette. A value that is not assessed or not a number is listed
  beside its chart, never drawn at zero. Each report page takes `{ paperclipUrl, approvalId, approvalStatus,
  takenAt }`; its one button links to `<paperclipUrl>/DAPP/approvals/<approvalId>`.
- `lib/serve.mjs`: the Worker's requests. **Fails closed**: a page only when Cloudflare Access authenticated the
  request (`ctx.access` set), else `403` with no report content. Every response carries `X-Robots-Tag: noindex,
  nofollow`, the pages' CSP (plus `frame-ancestors 'none'`), `Cache-Control: private, no-store` and
  `Referrer-Policy: no-referrer`. `/robots.txt` (disallow everything) is the one thing served without Access.
- `worker.mjs`, `wrangler.jsonc`: the `deroches-reports` Worker, on its `workers.dev` hostname, with
  `preview_urls: false` and **no Static Assets** (they don't pass `ctx.access` to the Worker). Never add `assets`.
- `build.mjs` (`npm run build`): the publish build. It reads every `MR-REPORT:` / `PL-EPICS:` approval and its
  linked issue's `research-report` / `epics-report` document from Paperclip, with the run's own
  `PAPERCLIP_API_URL`, `PAPERCLIP_API_KEY` and `PAPERCLIP_COMPANY_ID` (no other secret). It writes the pages to
  `generated/pages.mjs` (gitignored: no report is ever committed). A report that fails to parse fails the build,
  naming the approval and the document.
- `settings.json`: `paperclipUrl`, the Paperclip address each report's button opens on Richard's phone.
- `scripts/preview.mjs` (`npm run preview`): renders the test fixtures to `dist/` to look at the pages.
- `test/`: the parser's and the pages' tests, with fixtures shaped like the templates. One test reads the templates from the
  Studio clone (`STUDIO_CLONE`, default `/Volumes/Hermes/Studio/repos/deroches-studio`) to catch drift.

## Checks
```bash
npm ci
npm run lint
npm test
```

## Publishing a report
- **Who:** the Mobile Tech Lead, or Web & SEO (the agents allowed to deploy, `apps/RULES.md` section 1).
- **When:** once the Studio Director has filed the `MR-REPORT` or `PL-EPICS` approval. Publishing again later
  refreshes every page, including each approval's status.
- **Where:** `reports/` in a checkout of merged `main`: the worktree of the publish issue, cut from `main`.
  `npm run deploy` refuses anything else (HEAD must be the tip of `origin/main`, with no local change in `reports/`).
- **How:** one plain command each, from that checkout:

```bash
cd reports
```

```bash
npm ci
```

```bash
npm run deploy
```

`npm run deploy` runs `node build.mjs --from-main` and then `wrangler deploy`. If a report doesn't parse, nothing
is deployed: fix the document in Paperclip (its author) and run it again. The build's last line lists the pages
it published: check the new approval is there. If it stops at "not origin/main", bring the checkout up to date
(`git fetch origin main`, then `git merge --ff-only FETCH_HEAD`) and run it again.

Without Access the hostname answers `403` to everything but `/robots.txt`. Richard's Access application (the
Worker's **Access** tab, **All traffic**, a policy that admits only him) is what lets him in.

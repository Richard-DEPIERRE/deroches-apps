# ADR 0004: Richard's private report page — snapshot at publish, pages bundled in a Worker, Access in front

- Status: proposed
- Date: 2026-11-01
- Deciders: Mobile Tech Lead; Richard approves through the PR's approval stage
- Issue: DAPP-16 (mechanism chosen on DAPP-9, logged in the decision log)

## Context
Richard picks apps from the monthly research report and validates the week's epics from the Monday epics report.
Both are Paperclip issue documents written from `apps/handbook/templates/research-report.md` and `epics-report.md`.
The decision stays on the Paperclip approval the Studio Director files (handbook section 7). DAPP-9 chose a private,
read-only page that draws those reports as charts, with a **Decide in Paperclip** button for each report.

The facts that shape the design (checked 2026-11-01):
- Paperclip listens on `127.0.0.1` on the studio machine. A Worker on Cloudflare can't reach it unless Paperclip is
  exposed to the internet.
- Cloudflare can put Access in front of a whole Worker: the Worker's **Access** tab, **Protect this Worker behind
  Access**, **All traffic**. That covers its `workers.dev` hostname and its previews. When Access has not
  authenticated a request, the Worker's `ctx.access` is `undefined`. Static Assets don't pass `ctx.access` to the
  Worker (developers.cloudflare.com/workers/configuration/cloudflare-access/, read 2026-11-01).
- `preview_urls = false` in the Wrangler config turns off Version and Preview URLs
  (developers.cloudflare.com/workers/configuration/previews/, read 2026-11-01).
- Workers' free plan and Access's free plan (up to 50 users) cost $0.

## Decision
1. **Where:** `reports/` in `deroches-apps`. It is a Node package with the site kit's toolchain (Node 22, ES
   modules, `node --test`, Biome). It is not an app site and is not linked from one.
2. **Data feed: a snapshot taken when a report is published.** The publish step runs on the studio machine. It reads
   each `MR-REPORT:` / `PL-EPICS:` approval and its issue's `research-report` / `epics-report` document from the
   Paperclip API, with the run's own Paperclip credentials. It parses the template's tables (`reports/lib/`), renders
   the pages, and deploys them with `npm run deploy` from a `main` checkout. The deployed code is what is merged on
   `main`. The report text comes from Paperclip, which is the record. No report is committed to git, and the Worker
   holds no secret and no data store.
3. **The parser fails loudly.** A report that is missing a template section or column fails the publish with the
   name of what's missing. A cell that is `NOT ASSESSED`, or that has no number, has no value (`null`, never `0`),
   and the pages draw it as not assessed (handbook section 3). Each template's tables are tested, and a test reads
   the Studio clone's templates so drift shows up.
4. **The pages:** static HTML with the charts as inline SVG: the research bubble chart (beatability against
   French demand, sized by likely revenue at 6 months), the scores heat strip, the epics size-against-effect chart
   per app, and the cards. No client JavaScript, no cookies, no forms, no requests to other hosts. A strict CSP,
   `noindex` (meta tag, `X-Robots-Tag`, `robots.txt`), and a layout for a phone width first. Values that can't be
   plotted (not assessed or not a number) are listed beside the chart, never placed at zero. Each report's button
   links to `<Paperclip URL>/DAPP/approvals/<approval-id>`. The Paperclip URL is a build setting; Richard confirms
   it in the Access steps.
5. **Access:** Worker-level Access, **All traffic**, with a policy that admits Richard's account only. The Worker
   **fails closed**: it serves a page only when `ctx.access` is present, and answers `403` otherwise. That keeps the
   page private even if Access is turned off by mistake. The pages are bundled into the Worker as a module, not
   served as Static Assets, because Static Assets would bypass that check. `preview_urls: false`. The hostname is
   the Worker's own `workers.dev` name: no domain is bought (no public studio brand). Richard creates the Access
   application from a `needs-richard` issue with `richard-steps`.

Rejected:
- **Live read** (the Worker calls Paperclip with a read-only key held as a Worker secret). It would mean exposing
  Paperclip to the internet through a tunnel, a bigger attack surface than this page is worth, plus a secret to
  hold. Revisit only if Paperclip gets a public, authenticated API anyway.
- **Committing each snapshot to git.** Every report would wait for a code review and Richard's merge before he could
  see it, which turns the report itself into the gate.
- **KV or D1 for the reports.** A data store the issue rules out, and a second copy that could drift from Paperclip.
- **A chart library in the browser.** A script request and kilobytes for 4–8 points per chart. SVG drawn at build
  time works without JavaScript and loads instantly on a phone.
- **JWT checks against the Access team domain and AUD tag.** These need config that only exists after Richard's
  console step. `ctx.access` gives the same fail-closed guarantee with none.

## Consequences
- Publishing a report is one plain command by an agent allowed to deploy (Mobile Tech Lead, or Web & SEO), once
  the Studio Director has filed the approval. The PR that adds the deploy step documents the exact command.
- A report edited after publishing shows its old text until the next publish. Each page shows when it was taken.
  The Paperclip approval and document stay authoritative.
- The approval status shown on the page is the status when it was published. The button opens the live approval.
- Built in three PRs under DAPP-16 (the ~400-line rule): the parser (this ADR), then the pages and charts (with the
  Designer's review), then the Worker, the Access check and the publish step. A `needs-richard` issue for the
  Access application follows once the hostname exists.

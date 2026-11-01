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
- `test/`: the parser's tests, with fixtures shaped like the templates. One test reads the templates from the
  Studio clone (`STUDIO_CLONE`, default `/Volumes/Hermes/Studio/repos/deroches-studio`) to catch drift.

## Checks
```bash
npm ci
npm run lint
npm test
```

The pages, the Worker and the publish step come in the next PRs under DAPP-16.

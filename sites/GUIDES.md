# The daily guide, in the site kit

How a guide goes from the topic pick to a live page, with the kit's commands and paths. The rules: **one new guide per
app per day, and nothing publishes without `GATE CE-FACT-CHECK: PASS`.** A late guide is late, never unchecked. The
studio rules, the handbook (section 1, step 6), the `apps-daily-guide` skill and the `CE-FACT-CHECK` gate win over this
page; it only says how they map onto the kit. Every app with a site that isn't stopped gets this, every day, from the
`Daily guide run` routine (06:00 Europe/Paris, Web & SEO).

## 1. Pick the topic (Web & SEO)
One plain command each, the JSON in single quotes, an apostrophe written as the JSON escape `\u0027`; `gum describe <op>` first if
needed. The `siteUrl` is the app's own domain only; the `customerId` is typed from the `google-ads` document and never
copied anywhere.

```
gum read searchconsole.searchanalytics.query --args '{"siteUrl":"sc-domain:<domain>","startDate":"<28 days before the end>","endDate":"<3 days ago>","dimensions":["query"],"rowLimit":250}'
gum read searchconsole.searchanalytics.query --args '{"siteUrl":"sc-domain:<domain>","startDate":"<same>","endDate":"<same>","dimensions":["query","page"],"rowLimit":250}'
gum read googleads.keywordPlanIdeas.generateKeywordHistoricalMetrics --args '{"customerId":"<manager account id>","keywords":["<query 1>","<query 2>"],"geoTargetConstants":["2250"],"language":"1002"}'
```

Shortlist queries with at least 30 impressions, at most 1 click and a position over 10; check demand and season in
Keyword Planner. If one of our pages already ranks 11–20 for the query, improve that page instead (a correction, not a
new guide). A site under about 100 impressions: keyword research from the research report's head terms
(`googleads.keywordPlanIdeas.generateKeywordIdeas`). French by default; English when its evidence is clearly
stronger. Not a near-copy of an existing guide (`content/<lang>/guides/`), and not a topic that can only be answered as
personal advice.

## 2. The `guide` issue (Web & SEO → Content Editor)
A child of the app's `App:` issue, assigned to the Content Editor, with the handbook section 5 review policy (it ends
in a PR). It says:
- the target search and 3–5 variants from Keyword Planner;
- the language, and the other one if the guide also publishes in it (same translation key, one guide for the limit);
- the search intent, in one sentence;
- the 2–4 pages that already get traffic to link from (the top `page` rows by clicks);
- the publish date: a day with no other new guide on that site.

This issue's identifier (`DAPP-<n>`) is the guide's `factCheck`.

## 3. Write it (Content Editor)
On the issue's branch (`studio/<identifier>-<slug>`), from `sites/`:

```
npm run new-guide -- <slug> fr <file-slug> --date <publish date>
npm run new-guide -- <slug> en <file-slug> --translation <the French file's translation key> --date <publish date>
```

It writes `<slug>/content/<lang>/guides/<file-slug>.md` (the URL is `/guides/<file-slug>/`, or `/en/guides/…`) with
the front matter to fill: `title`, `description`, `translation`, `type: guide`, `published`, `updated`, `factCheck`,
`sources` (title, publisher, url, source_date, read, as the fact-check recorded them), an optional `download` line
and an optional `related` list.
The kit's README has the format. Open a draft PR; run `CE-FACT-CHECK` in each language and post
`GATE CE-FACT-CHECK: <VERDICT>` on the issue. Only `PASS` goes on.

## 4. Links, download buttons, sitemap (Web & SEO, after `PASS`)
On the same PR:
- **Into the guide**: a sentence with descriptive anchor text in 2–4 of the pages named in the issue.
  **Out of it**: 2–3 related guides of the same site, as the `related:` translation keys (the build refuses a key
  that isn't another guide in that language, and any broken internal link). Never another app's site.
- **Download blocks**: move the `<!-- download -->` line where readers stop reading (the read-depth query in the
  README); before there's data, right after the section that answers the main question. The banner at the end is the
  kit's.
- **Sitemap**: nothing to write. The build regenerates `sitemap.xml` with each page's `lastmod` and alternates.
- Neither changes a claim. Any other change to the guide's wording after `PASS` needs a new check.

Then `npm test` (it runs `check-guides`) and `npm run build -- <slug>`, and mark the PR ready.

## 5. What CI checks, and what the reviewer checks
`npm run check-guides` runs in `npm test`, so in CI, over every `sites/<slug>/`:
- **at most one new guide per `published` date** per site. The French and English pages of one guide (same
  `translation`) count as one; a translation published on a later day counts on that day;
- every guide has `factCheck: DAPP-<n>` and sources with a URL, publisher, source date and read date (the build's own
  guide checks).

It can't read Paperclip. **The reviewer opens the `factCheck` issue and confirms its latest gate comment is
`GATE CE-FACT-CHECK: PASS`, covering each language in the PR, before approving.** No `PASS`: request changes.

## 6. Publish (Web & SEO, after merge)
Only what is merged on `main`. Change directory in its own command, then deploy as one plain command:

```
cd sites/<slug>
npx wrangler deploy
```

Then check the live page (canonical, hreflang, store buttons) and:

```
gum read searchconsole.urlInspection.index.inspect --args '{"inspectionUrl":"https://<domain>/guides/<file-slug>/","siteUrl":"sc-domain:<domain>"}'
gum read searchconsole.sitemaps.list --args '{"siteUrl":"sc-domain:<domain>"}'
```

A new URL is unknown to Google at first; look again over the next days. Richard submits the sitemap; ask him
(`needs-richard`) only if it is missing, or has errors or was never fetched 7 days after the site went live.

**A late guide**: when `PASS` comes after the planned date, set `published` and `updated` to the day it actually goes
live, a day with no other new guide; `check-guides` refuses a clash.

## 7. The routine comment
Once per run, on the routine's issue: each app's topic picked today (search, language, `guide` issue), and yesterday's
guides published (URL) or late (why).

## 8. A wrong guide live
An emergency (rules section 6):
1. Unpublish at once: from `sites/<slug>/`, `npx wrangler versions list`, then
   `npx wrangler versions deploy <last good version-id>`. Open the revert PR, so `main` matches.
2. Raise a `critical` Studio HQ issue labelled `emergency` for the Studio Director: what, since when, impact, what you
   did.
3. Within 24 hours: correct it, `CE-FACT-CHECK` again on the same `guide` issue, republish. A correction keeps its
   `published` date and moves `updated`: it is not a new guide.

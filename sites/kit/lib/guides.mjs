import { langPrefix } from './config.mjs';
import { escapeHtml as e } from './html.mjs';
import { longDate, STRINGS } from './i18n.mjs';

const DATE = /^\d{4}-\d{2}-\d{2}$/;
/** A front-matter date as text (YAML may read a year as a number). */
const asDate = (value) =>
  value instanceof Date
    ? value.toISOString().slice(0, 10)
    : typeof value === 'number'
      ? String(value)
      : value;
const text = (value) => typeof value === 'string' && value.trim() !== '';

/** The hub of a language's guides: /guides/ and /en/guides/ (translation key `guides`). */
export const hubPath = (lang) => `${langPrefix(lang)}/guides/`;

/**
 * Checks a guide's front matter and fills `published`, `updated` (defaults to `published`), `sources` and `download` on
 * the page. A guide publishes only after `GATE CE-FACT-CHECK: PASS` on its `guide` issue (`factCheck`),
 * and lists the dated sources the fact-check recorded (apps-fact-check). Returns the problems.
 */
export function checkGuide(page) {
  const { data } = page;
  const problems = [];
  page.published = asDate(data.published);
  if (!DATE.test(page.published ?? '')) problems.push('published: YYYY-MM-DD is required on a guide');
  if (!/^DAPP-\d+$/.test(data.factCheck ?? ''))
    problems.push(
      'factCheck: DAPP-<n>, the guide issue with GATE CE-FACT-CHECK: PASS, is required on a guide',
    );
  page.updated ??= page.published;
  if (page.updated < page.published) problems.push('updated: not before published');
  if (/<h1\b/i.test(page.html)) problems.push('a guide has no # heading of its own: its H1 is the title');
  page.sources = Array.isArray(data.sources) ? data.sources : [];
  if (!page.sources.length) problems.push('sources: at least one, as the fact-check recorded them');
  page.sources.forEach((source, i) => {
    for (const key of ['title', 'publisher', 'source_date'])
      if (!text(asDate(source?.[key]))) problems.push(`sources[${i}].${key} is required`);
    if (!/^https:\/\/\S+$/.test(source?.url ?? '')) problems.push(`sources[${i}].url: an https URL`);
    if (!DATE.test(asDate(source?.read) ?? ''))
      problems.push(`sources[${i}].read: YYYY-MM-DD, the day it was read`);
  });
  if (data.download !== undefined && !text(data.download))
    problems.push('download: one line on what the app does for this reader');
  page.download = data.download;
  return problems;
}

/**
 * The one-a-day rule (GUIDES.md): at most one new guide per site per `published` date. The French and English pages of
 * one guide share a translation key and count as one; a correction moves only `updated`, so it is not a new guide.
 * Returns the problems, one per day with more than one.
 */
export function oneGuidePerDay(pages) {
  const days = new Map();
  for (const page of pages.filter((p) => p.type === 'guide')) {
    const guides = days.get(page.published) ?? new Map();
    const key = page.translation ?? page.file;
    guides.set(key, [...(guides.get(key) ?? []), page.file]);
    days.set(page.published, guides);
  }
  return [...days]
    .filter(([, guides]) => guides.size > 1)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(
      ([day, guides]) =>
        `published ${day}: ${guides.size} new guides, at most one a day per site (${[...guides.values()]
          .flat()
          .join(', ')}); move the others to later days`,
    );
}

/** A language's indexable guides, newest first. */
export function guidesOf(pages, lang) {
  return pages
    .filter((p) => p.lang === lang && p.type === 'guide' && !p.noindex)
    .sort((a, b) => b.published.localeCompare(a.published) || a.title.localeCompare(b.title));
}

/** The kit's hub page of a language, unless the site has its own (`content/<lang>/guides/index.md`). */
export function hubPage(lang, site) {
  const t = STRINGS[lang];
  const path = hubPath(lang);
  return {
    lang,
    file: `(kit) ${path}`,
    path,
    url: `${site.origin}${path}`,
    title: t.guides,
    description: t.guidesDescription(site.name[lang]),
    type: 'page',
    translation: 'guides',
    noindex: false,
    data: {},
    html: `<h1>${e(t.guides)}</h1>\n`,
  };
}

/** The hub's list. A hub without guides stays out of search; its date is its newest guide's. */
export function fillHub(hub, pages) {
  const guides = guidesOf(pages, hub.lang);
  hub.noindex ||= guides.length === 0;
  hub.updated =
    guides
      .map((g) => g.updated)
      .sort()
      .at(-1) ?? hub.updated;
  hub.html += `<ul class="guide-list">${guides
    .map((g) => `<li><a href="${e(g.path)}">${e(g.title)}</a><span>${e(g.description)}</span></li>`)
    .join('')}</ul>\n`;
}

/**
 * The store buttons of a live site: plain text in the page's language (no store artwork), one per store with a URL,
 * each through the counted redirect /go/<store>?from=<page path>. Nothing before launch.
 */
export function storeButtons(site, lang, path) {
  if (site.status !== 'live') return '';
  const links = ['ios', 'android']
    .filter((store) => site.stores?.[store])
    .map(
      (store) =>
        `<a class="store-button" href="/go/${store}?from=${e(encodeURIComponent(path))}" rel="nofollow">${e(STRINGS[lang].stores[store])}</a>`,
    );
  return `<p class="store-buttons">${links.join('')}</p>`;
}

/** What follows a download block's words: the store buttons, or before launch a plain "coming soon" line. */
function cta(site, lang, path) {
  return storeButtons(site, lang, path) || `<p class="coming-soon">${e(STRINGS[lang].comingSoon)}</p>`;
}

/**
 * A guide's main column: breadcrumb, H1 from the title, its dates, the body with each `<!-- download -->` line turned
 * into a download block, the app banner, then the sources.
 */
export function guideMain(page, site) {
  const { lang } = page;
  const t = STRINGS[lang];
  const name = site.name[lang];
  const tagline = site.tagline[lang];
  const date = (iso) => `<time datetime="${iso}">${e(longDate(lang, iso))}</time>`;
  const dates = `${e(t.published)} ${date(page.published)}${
    page.updated > page.published ? ` · ${e(t.updated)} ${date(page.updated)}` : ''
  }`;
  const download = `<aside class="download"><p>${e(page.download ?? tagline)}</p>${cta(site, lang, page.path)}</aside>\n`;
  const body = page.html.replace(/<!--\s*download\s*-->\n?/g, download);
  const sources = page.sources
    .map(
      (s) =>
        `<li><a href="${e(s.url)}">${e(s.title)}</a>, ${e(s.publisher)}, ${DATE.test(asDate(s.source_date)) ? date(asDate(s.source_date)) : e(s.source_date)} (${e(t.read)} ${date(asDate(s.read))})</li>`,
    )
    .join('');
  return `<nav class="breadcrumb" aria-label="${e(t.breadcrumb)}"><a href="${langPrefix(lang)}/">${e(t.home)}</a> <span aria-hidden="true">›</span> <a href="${hubPath(lang)}">${e(t.guides)}</a></nav>
<h1>${e(page.title)}</h1>
<p class="updated">${dates}</p>
${body}<aside class="app-banner" aria-label="${e(name)}"><p><strong>${e(name)}</strong> — ${e(tagline)}</p>${cta(site, lang, page.path)}</aside>
<section class="sources" aria-labelledby="sources"><h2 id="sources">${e(t.sources)}</h2><ol>${sources}</ol></section>
`;
}

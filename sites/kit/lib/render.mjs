import { LANGS, langPrefix } from './config.mjs';
import { escapeHtml as e, jsonForScript } from './html.mjs';
import { STRINGS } from './i18n.mjs';
import { alternates, structuredData } from './seo.mjs';

/** The link to the same page in the other language, or to that language's home page when there is none. */
function languageSwitch(page) {
  return LANGS.filter((lang) => lang !== page.lang)
    .map((lang) => {
      const target = page.translations[lang];
      const href = target ? target.path : `${langPrefix(lang)}/`;
      return `<a href="${e(href)}" hreflang="${lang}" lang="${lang}">${e(STRINGS[lang].otherLanguage)}</a>`;
    })
    .join(' ');
}

/** The footer with the legal pages of the page's language; no footer at all when there are none (no empty rule). */
function footer(page, pages) {
  const legal = pages.filter((p) => p.lang === page.lang && p.type === 'legal');
  if (!legal.length) return '';
  const items = legal.map((p) => `<li><a href="${e(p.path)}">${e(p.title)}</a></li>`).join('');
  return `<footer class="site-footer">
<nav aria-label="${e(STRINGS[page.lang].legal)}"><ul>${items}</ul></nav>
</footer>
`;
}

/**
 * The whole HTML document for a page. `page` needs lang, path, url, title, description, html,
 * translations; `ctx` holds the site, every page (for the footer) and the stylesheet's hashed path.
 */
export function renderPage(page, { site, pages, stylesheet }) {
  const t = STRINGS[page.lang];
  const appName = site.name[page.lang];
  const title = page.type === 'home' ? page.title : `${page.title} | ${appName}`;
  const head = [
    '<meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    `<title>${e(title)}</title>`,
    `<meta name="description" content="${e(page.description)}">`,
    page.noindex ? '<meta name="robots" content="noindex">' : `<link rel="canonical" href="${e(page.url)}">`,
    ...(page.noindex ? [] : alternates(page)).map(
      (alt) => `<link rel="alternate" hreflang="${alt.hreflang}" href="${e(alt.href)}">`,
    ),
    `<meta property="og:type" content="${page.type === 'guide' ? 'article' : 'website'}">`,
    `<meta property="og:site_name" content="${e(appName)}">`,
    `<meta property="og:title" content="${e(page.title)}">`,
    `<meta property="og:description" content="${e(page.description)}">`,
    `<meta property="og:url" content="${e(page.url)}">`,
    `<meta property="og:locale" content="${t.locale}">`,
    ...['light', 'dark'].map(
      (scheme) =>
        `<meta name="theme-color" media="(prefers-color-scheme: ${scheme})" content="${e(site.accent[scheme])}">`,
    ),
    `<link rel="stylesheet" href="${e(stylesheet)}">`,
    ...structuredData(page, site).map(
      (data) => `<script type="application/ld+json">${jsonForScript(data)}</script>`,
    ),
  ].filter(Boolean);
  return `<!doctype html>
<html lang="${page.lang}">
<head>
${head.join('\n')}
</head>
<body class="type-${page.type}">
<a class="skip" href="#main">${e(t.skip)}</a>
<header class="site-header">
<a class="brand" href="${langPrefix(page.lang)}/">${e(appName)}</a>
<nav class="lang" aria-label="${e(t.language)}">${languageSwitch(page)}</nav>
</header>
<main id="main">
${page.html}
</main>
${footer(page, pages)}</body>
</html>
`;
}

/** The not-found page of a language (served by Cloudflare for any missing URL under that language). */
export function notFoundPage(lang, site) {
  const t = STRINGS[lang];
  const path = `${langPrefix(lang)}/404.html`;
  return {
    lang,
    path,
    url: `${site.origin}${path}`,
    title: t.notFoundTitle,
    description: t.notFoundText,
    type: 'page',
    noindex: true,
    translations: {},
    html: `<h1>${e(t.notFoundTitle)}</h1>\n<p>${e(t.notFoundText)}</p>\n<p><a href="${langPrefix(lang)}/">${e(t.backHome)}</a></p>`,
  };
}

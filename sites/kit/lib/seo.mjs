import { DEFAULT_LANG, LANGS, langPrefix } from './config.mjs';
import { hubPath } from './guides.mjs';
import { escapeHtml } from './html.mjs';
import { STRINGS } from './i18n.mjs';

/** Every language version of a page, itself included, as [lang, page] pairs in the order of LANGS. */
export function versions(page) {
  const all = { ...page.translations, [page.lang]: page };
  return LANGS.filter((lang) => all[lang]).map((lang) => [lang, all[lang]]);
}

/** hreflang alternates: one per language version plus x-default (the French one), only when a translation exists. */
export function alternates(page) {
  const all = versions(page);
  if (all.length < 2) return [];
  const fallback = all.find(([lang]) => lang === DEFAULT_LANG)?.[1] ?? page;
  return [
    ...all.map(([lang, p]) => ({ hreflang: lang, href: p.url })),
    { hreflang: 'x-default', href: fallback.url },
  ];
}

/** Structured data for a page (schema.org JSON-LD). Never ratings or reviews we don't have. */
export function structuredData(page, site) {
  if (page.type === 'guide') return guideData(page, site);
  if (page.type !== 'home') return [];
  const name = site.name[page.lang];
  const data = [
    { '@context': 'https://schema.org', '@type': 'WebSite', name, url: page.url, inLanguage: page.lang },
  ];
  const stores = Object.entries(site.stores ?? {}).filter(([, url]) => url);
  if (site.status === 'live' && stores.length) {
    data.push({
      '@context': 'https://schema.org',
      '@type': 'MobileApplication',
      name,
      url: page.url,
      operatingSystem: stores.map(([store]) => (store === 'ios' ? 'iOS' : 'Android')).join(', '),
      applicationCategory: site.category ?? 'UtilitiesApplication',
      offers: { '@type': 'Offer', price: '0', priceCurrency: 'EUR' },
      sameAs: stores.map(([, url]) => url),
    });
  }
  return data;
}

/** A guide: an Article published by the app's site (no invented author), and its breadcrumb (home, guides, guide). */
function guideData(page, site) {
  const home = `${site.origin}${langPrefix(page.lang)}/`;
  const crumbs = [
    [STRINGS[page.lang].home, home],
    [STRINGS[page.lang].guides, `${site.origin}${hubPath(page.lang)}`],
    [page.title, page.url],
  ];
  return [
    {
      '@context': 'https://schema.org',
      '@type': 'Article',
      headline: page.title,
      description: page.description,
      datePublished: page.published,
      dateModified: page.updated,
      inLanguage: page.lang,
      mainEntityOfPage: page.url,
      publisher: { '@type': 'Organization', name: site.name[page.lang], url: home },
    },
    {
      '@context': 'https://schema.org',
      '@type': 'BreadcrumbList',
      itemListElement: crumbs.map(([name, item], i) => ({
        '@type': 'ListItem',
        position: i + 1,
        name,
        item,
      })),
    },
  ];
}

export function sitemap(pages) {
  const urls = pages
    .filter((p) => !p.noindex)
    .sort((a, b) => a.path.localeCompare(b.path))
    .map((page) => {
      const lines = [`    <loc>${escapeHtml(page.url)}</loc>`];
      if (page.updated) lines.push(`    <lastmod>${page.updated}</lastmod>`);
      for (const alt of alternates(page)) {
        lines.push(
          `    <xhtml:link rel="alternate" hreflang="${alt.hreflang}" href="${escapeHtml(alt.href)}"/>`,
        );
      }
      return `  <url>\n${lines.join('\n')}\n  </url>`;
    });
  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
${urls.join('\n')}
</urlset>
`;
}

/** The store-click redirects and the beacon are kept out of crawls, so bots don't count as readers. */
export function robots(site) {
  return `User-agent: *\nAllow: /\nDisallow: /go/\nDisallow: /a$\n\nSitemap: ${site.origin}/sitemap.xml\n`;
}

/**
 * Response headers for the static assets. The CSP allows nothing from other origins and no forms at all:
 * the sites collect no personal data, and no third-party script can be added by mistake.
 */
export function headers() {
  return `/*
  Content-Security-Policy: default-src 'self'; img-src 'self' data:; script-src 'self'; style-src 'self'; connect-src 'self'; form-action 'none'; frame-ancestors 'none'; base-uri 'self'
  Referrer-Policy: strict-origin-when-cross-origin
  X-Content-Type-Options: nosniff
  Permissions-Policy: camera=(), microphone=(), geolocation=()

/assets/*
  Cache-Control: public, max-age=31536000, immutable
`;
}

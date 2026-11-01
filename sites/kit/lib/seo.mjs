import { DEFAULT_LANG, LANGS } from './config.mjs';
import { escapeHtml } from './html.mjs';

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

export function robots(site) {
  return `User-agent: *\nAllow: /\n\nSitemap: ${site.origin}/sitemap.xml\n`;
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

import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

/** French is the default language and lives at the root; every other language lives under /<lang>/. */
export const LANGS = ['fr', 'en'];
export const DEFAULT_LANG = 'fr';

export const SLUG = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const DOMAIN = /^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$/;
const STATUSES = ['coming-soon', 'live'];
const STORES = ['ios', 'android'];

/** Reads and checks `<siteDir>/site.json`. Throws one error listing every problem. */
export async function loadSite(siteDir) {
  const file = join(siteDir, 'site.json');
  const site = JSON.parse(await readFile(file, 'utf8'));
  const errors = [];
  if (!SLUG.test(site.slug ?? '')) errors.push('slug: lowercase letters, digits and hyphens');
  if (!DOMAIN.test(site.domain ?? '')) errors.push('domain: a bare domain such as example.fr');
  if (!STATUSES.includes(site.status)) errors.push(`status: one of ${STATUSES.join(', ')}`);
  for (const lang of LANGS) {
    if (!site.name?.[lang]) errors.push(`name.${lang} is required`);
  }
  if (site.themeColor !== undefined && !/^#[0-9a-f]{6}$/i.test(site.themeColor)) {
    errors.push('themeColor: #rrggbb');
  }
  for (const [store, url] of Object.entries(site.stores ?? {})) {
    if (!STORES.includes(store)) errors.push(`stores.${store}: only ${STORES.join(', ')}`);
    else if (url !== null && !/^https:\/\/\S+$/.test(url))
      errors.push(`stores.${store}: an https URL or null`);
  }
  if (site.status === 'live' && !STORES.some((s) => site.stores?.[s])) {
    errors.push('stores: a live site needs at least one store URL');
  }
  if (errors.length) throw new Error(`${file}:\n- ${errors.join('\n- ')}`);
  return { ...site, origin: `https://${site.domain}` };
}

/** The URL prefix of a language: '' for French, '/en' for English. */
export function langPrefix(lang) {
  return lang === DEFAULT_LANG ? '' : `/${lang}`;
}

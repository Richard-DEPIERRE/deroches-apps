import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

/** French is the default language and lives at the root; every other language lives under /<lang>/. */
export const LANGS = ['fr', 'en'];
export const DEFAULT_LANG = 'fr';

export const SLUG = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const DOMAIN = /^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$/;
const STATUSES = ['coming-soon', 'live'];
const STORES = ['ios', 'android'];
const HEX = /^#[0-9a-f]{6}$/i;

/** The page background of each colour scheme, as `site.css` sets it; each site's accent must read on it. */
export const BACKGROUNDS = { light: '#ffffff', dark: '#111113' };
/** WCAG AA for normal text: links are text. */
export const MIN_CONTRAST = 4.5;

function luminance(hex) {
  const [r, g, b] = [1, 3, 5].map((i) => {
    const c = Number.parseInt(hex.slice(i, i + 2), 16) / 255;
    return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/** The WCAG 2.x contrast ratio of two #rrggbb colours (1 to 21). */
export function contrast(a, b) {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
}

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
    if (typeof site.tagline?.[lang] !== 'string' || !site.tagline[lang].trim())
      errors.push(`tagline.${lang} is required: one line on what the app does (app banner, download blocks)`);
    if (typeof site.appData?.[lang] !== 'string' || !site.appData[lang].trim())
      errors.push(`appData.${lang} is required: what the app collects, for the privacy policy`);
  }
  if (!/^[^\s@<>"]+@[^\s@<>"]+\.[a-z]{2,}$/i.test(site.supportEmail ?? ''))
    errors.push("supportEmail: the app's support address (the privacy rights contact)");
  if (site.replyWithinWorkingDay !== undefined && typeof site.replyWithinWorkingDay !== 'boolean')
    errors.push('replyWithinWorkingDay: true or false (true only once Support confirms it)');
  if (site.themeColor !== undefined) errors.push('themeColor: replaced by accent.light and accent.dark');
  for (const [scheme, bg] of Object.entries(BACKGROUNDS)) {
    const color = site.accent?.[scheme];
    if (!HEX.test(color ?? '')) {
      errors.push(`accent.${scheme} is required: #rrggbb, this app's own colour (no shared studio colour)`);
      continue;
    }
    const ratio = contrast(color, bg);
    if (ratio < MIN_CONTRAST) {
      errors.push(
        `accent.${scheme}: ${color} on ${bg} is ${ratio.toFixed(2)}:1, under ${MIN_CONTRAST}:1 (links use it)`,
      );
    }
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

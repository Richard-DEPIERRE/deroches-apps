import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { marked } from 'marked';
import { escapeHtml as e } from './html.mjs';
import { STRINGS } from './i18n.mjs';

const KIT = dirname(dirname(fileURLToPath(import.meta.url)));
/** Richard's file (sites/legal/README.md). Agents never create, fill or copy it. */
export const IDENTITY_FILE = join(dirname(KIT), 'legal', 'identity.json');
export const TEMPLATES = join(KIT, 'templates', 'legal');

/** The three legal pages every site has in every language: translation key, then the file (and URL) per language. */
export const LEGAL = [
  { key: 'legal-notice', fr: 'mentions-legales', en: 'legal-notice' },
  { key: 'privacy', fr: 'confidentialite', en: 'privacy' },
  { key: 'terms', fr: 'conditions', en: 'terms' },
];

const REQUIRED = [
  'publisher.name',
  'publisher.legalForm',
  'publisher.address',
  'publisher.email',
  'publisher.phone',
  'publisher.registration',
  'publicationDirector',
  'host.name',
  'host.address',
  'host.phone',
];
const OPTIONAL = ['publisher.shareCapital', 'publisher.vatNumber'];
const get = (data, field) => field.split('.').reduce((v, k) => v?.[k], data);
const filled = (value) => typeof value === 'string' && value.trim() !== '';

/**
 * Reads the identity file. Returns `{ identity }`, or `{ problem }` for a review build; a production build throws
 * instead. Problems name fields, never values.
 */
export async function loadIdentity(file, production) {
  let problem;
  try {
    const identity = JSON.parse(await readFile(file, 'utf8'));
    const bad = [
      ...REQUIRED.filter((f) => !filled(get(identity, f))),
      ...OPTIONAL.filter((f) => get(identity, f) !== undefined && !filled(get(identity, f))),
    ];
    if (!bad.length) return { identity };
    problem = `${file}: missing or empty ${bad.join(', ')}`;
  } catch (error) {
    problem = error.code === 'ENOENT' ? `${file} is missing` : `${file}: ${error.message}`;
  }
  if (production)
    throw new Error(`The legal notice can't be deployed without Richard's identity file: ${problem}`);
  return { problem };
}

const lines = (value) => e(value).replace(/\r?\n/g, '<br>');

function identityHtml(lang, { identity }) {
  const t = STRINGS[lang];
  if (!identity) return `<p class="identity-missing"><strong>${e(t.identityMissing)}</strong></p>`;
  const row = (label, value) => (value ? `<dt>${e(label)}</dt><dd>${lines(value)}</dd>` : '');
  const { publisher: p, host: h } = identity;
  return `<h2>${e(t.publisher)}</h2>
<dl>${row(t.name, p.name)}${row(t.legalForm, p.legalForm)}${row(t.shareCapital, p.shareCapital)}${row(t.address, p.address)}${row(t.email, p.email)}${row(t.phone, p.phone)}${row(t.registration, p.registration)}${row(t.vatNumber, p.vatNumber)}${row(t.publicationDirector, identity.publicationDirector)}</dl>
<h2>${e(t.host)}</h2>
<dl>${row(t.name, h.name)}${row(t.address, h.address)}${row(t.phone, h.phone)}</dl>`;
}

/**
 * Fills the legal pages' placeholders from site.json and the identity file. The legal notice always carries the
 * identity block (appended when an overriding page leaves out `{{identity}}`); without the file it shows a visible
 * placeholder and stays out of search.
 */
export function fillLegal(pages, site, identity) {
  for (const page of pages.filter((p) => p.type === 'legal')) {
    const lang = page.lang;
    const email = e(site.supportEmail);
    const date = page.updated && new Date(`${page.updated}T00:00:00Z`);
    const long = new Intl.DateTimeFormat(STRINGS[lang].locale.replace('_', '-'), {
      dateStyle: 'long',
      timeZone: 'UTC',
    });
    const values = {
      name: e(site.name[lang]),
      domain: e(site.domain),
      support: `<a href="mailto:${email}">${email}</a>`,
      updated: date && e(long.format(date)),
      appData: marked.parse(site.appData[lang]),
      identity: identityHtml(lang, identity),
    };
    let html = page.html.replace(/<p>\{\{(appData|identity)\}\}<\/p>/g, '{{$1}}');
    if (page.translation === 'legal-notice') {
      if (!html.includes('{{identity}}')) html += '\n{{identity}}';
      if (!identity.identity) page.noindex = true;
    }
    html = html.replace(/\{\{(\w+)\}\}/g, (match, key) => {
      if (values[key] === undefined) throw new Error(`${page.file}: ${match} is unknown or has no value`);
      return values[key];
    });
    // The date sits in the same place on every legal page: its own line under the title.
    if (values.updated) {
      const line = `<p class="updated">${e(STRINGS[lang].lastUpdated)} ${values.updated}</p>`;
      html = html.includes('</h1>') ? html.replace('</h1>', `</h1>\n${line}`) : `${line}\n${html}`;
    }
    page.html = html;
  }
}

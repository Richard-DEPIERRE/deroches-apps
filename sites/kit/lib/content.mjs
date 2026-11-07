import { readdir, readFile } from 'node:fs/promises';
import { join, relative } from 'node:path';
import { marked } from 'marked';
import YAML from 'yaml';
import { LANGS, langPrefix, SLUG } from './config.mjs';
import { checkGuide, fillHub, hubPage, hubPath, linkRelated } from './guides.mjs';
import { KIT_PAGES, TEMPLATES } from './legal.mjs';
import { markdownProblems } from './links.mjs';

const TYPES = ['home', 'page', 'guide', 'legal'];
const DATE = /^\d{4}-\d{2}-\d{2}$/;

async function markdownFiles(dir) {
  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true, recursive: true });
  } catch (error) {
    if (error.code === 'ENOENT') return [];
    throw error;
  }
  return entries
    .filter((e) => e.isFile() && e.name.endsWith('.md'))
    .map((e) => join(e.parentPath, e.name))
    .sort();
}

export function parseFrontMatter(source, file) {
  const match = /^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/.exec(source);
  if (!match) throw new Error(`${file}: starts without a front matter block (--- ... ---)`);
  return { data: YAML.parse(match[1]) ?? {}, body: source.slice(match[0].length) };
}

/** content/<lang>/a/b.md -> /a/b/ (French) or /en/a/b/; index.md is its folder's page. */
export function pathFor(lang, rel, file) {
  const parts = rel.replace(/\.md$/, '').split(/[\\/]/);
  if (parts.at(-1) === 'index') parts.pop();
  for (const part of parts) {
    if (!SLUG.test(part)) throw new Error(`${file}: "${part}" is not a URL slug (a-z, 0-9, hyphens)`);
  }
  return `${langPrefix(lang)}/${parts.map((p) => `${p}/`).join('')}`;
}

function asDate(value) {
  return value instanceof Date ? value.toISOString().slice(0, 10) : value;
}

/** Wide tables scroll sideways in their own box instead of pushing the page past a phone's width. */
const scrollTables = (html) =>
  html
    .replaceAll('<table>', '<div class="table-scroll" tabindex="0"><table>')
    .replaceAll('</table>', '</table></div>');

function toPage(lang, file, rel, source, site, ownContent = true) {
  const { data, body } = parseFrontMatter(source, file);
  const path = pathFor(lang, rel, file);
  const isHome = path === `${langPrefix(lang)}/`;
  const page = {
    lang,
    file,
    path,
    url: `${site.origin}${path}`,
    title: data.title,
    description: data.description,
    type: data.type ?? (isHome ? 'home' : 'page'),
    translation: data.translation,
    updated: asDate(data.updated),
    noindex: data.noindex === true,
    data,
    html: scrollTables(marked.parse(body)),
  };
  const errors = [];
  if (typeof page.title !== 'string' || !page.title.trim()) errors.push('title is required');
  if (typeof page.description !== 'string' || !page.description.trim())
    errors.push('description is required');
  if (!TYPES.includes(page.type)) errors.push(`type: one of ${TYPES.join(', ')}`);
  if (page.updated !== undefined && !DATE.test(page.updated)) errors.push('updated: YYYY-MM-DD');
  if (page.translation !== undefined && !SLUG.test(page.translation)) errors.push('translation: a slug');
  if (page.type === 'guide') errors.push(...checkGuide(page));
  errors.push(...markdownProblems(page.html, page, site, { ownContent }));
  if (errors.length) throw new Error(`${file}:\n- ${errors.join('\n- ')}`);
  return page;
}

/**
 * Loads every page of a site and pairs translations: pages in different languages that share a
 * `translation` key are each other's translations (each home page pairs automatically).
 */
export async function loadPages(siteDir, site) {
  const pages = [];
  for (const lang of LANGS) {
    const root = join(siteDir, 'content', lang);
    for (const file of await markdownFiles(root)) {
      pages.push(toPage(lang, file, relative(root, file), await readFile(file, 'utf8'), site));
    }
    // Every language gets the kit's pages (support, legal): the kit's template, unless the site overrides the page.
    for (const kit of KIT_PAGES) {
      const rel = `${kit[lang]}.md`;
      const own = pages.find((p) => p.path === pathFor(lang, rel, rel));
      if (own && (own.type !== kit.type || own.translation !== kit.key)) {
        const what = kit.type === 'legal' ? 'a legal page' : `the ${kit.key} page`;
        throw new Error(`${own.file}: ${what} needs type: ${kit.type} and translation: ${kit.key}`);
      }
      if (own) continue;
      const file = join(TEMPLATES, kit.dir, lang, rel);
      pages.push(toPage(lang, file, rel, await readFile(file, 'utf8'), site, false));
    }
    // The guides hub: the kit's, or the site's own content/<lang>/guides/index.md, with the list added.
    const hub = pages.find((p) => p.path === hubPath(lang));
    if (hub && hub.translation !== 'guides')
      throw new Error(`${hub.file}: the guides hub needs translation: guides`);
    if (!hub) pages.push(hubPage(lang, site));
  }
  linkRelated(pages);
  for (const hub of pages.filter((p) => p.translation === 'guides')) fillHub(hub, pages);
  const byPath = new Map();
  const groups = new Map();
  for (const page of pages) {
    if (byPath.has(page.path)) throw new Error(`${page.file}: same URL as ${byPath.get(page.path).file}`);
    byPath.set(page.path, page);
    const key = page.type === 'home' ? (page.translation ?? 'home') : page.translation;
    if (!key) continue;
    const group = groups.get(key) ?? {};
    if (group[page.lang])
      throw new Error(`${page.file}: translation "${key}" is also used by ${group[page.lang].file}`);
    group[page.lang] = page;
    groups.set(key, group);
  }
  for (const lang of LANGS) {
    if (!byPath.has(`${langPrefix(lang)}/`))
      throw new Error(`${siteDir}: content/${lang}/index.md is missing`);
  }
  for (const page of pages) {
    if (site.status === 'coming-soon' && page.type === 'home' && !page.html.includes('<p>'))
      throw new Error(`${page.file}: a coming-soon home page says what the app will do, in a paragraph`);
  }
  for (const page of pages) {
    const key = page.type === 'home' ? (page.translation ?? 'home') : page.translation;
    const group = key ? groups.get(key) : {};
    page.translations = Object.fromEntries(Object.entries(group).filter(([lang]) => lang !== page.lang));
  }
  return pages;
}

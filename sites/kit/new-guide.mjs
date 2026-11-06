#!/usr/bin/env node
// Starts a guide (GUIDES.md): node kit/new-guide.mjs <slug> <lang> <file-slug> [--translation <key>] [--date YYYY-MM-DD]
// Writes sites/<slug>/content/<lang>/guides/<file-slug>.md with its front matter ready to fill. The build and
// check-guides refuse it until its title, description, factCheck and sources are filled in.
import { access, mkdir, writeFile } from 'node:fs/promises';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';
import { LANGS, SLUG } from './lib/config.mjs';

const SITES = dirname(dirname(fileURLToPath(import.meta.url)));
const DATE = /^\d{4}-\d{2}-\d{2}$/;

/** Today in Paris (YYYY-MM-DD), the studio's day: the Daily guide run starts at 06:00 Europe/Paris. */
export const parisToday = (now = new Date()) =>
  new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Paris' }).format(now);

/** A new guide's file: the front matter to fill, then a download block to move where readers stop reading. */
export const guideTemplate = ({ translation, date }) => `---
title: ''        # the target search in natural words, about 50-60 characters (the H1)
description: ''  # about 120-160 characters (the meta description)
translation: ${translation}  # the same key on the French and the English page of this guide
type: guide
published: ${date}  # the day it goes live: one new guide per site per day
updated: ${date}    # a correction moves only this date, never published
factCheck: ''    # DAPP-<n>: the guide issue with GATE CE-FACT-CHECK: PASS
sources: []      # as the fact-check recorded them: title, publisher, url, source_date, read
# download: one line on what the app does for this reader (default: the site's tagline)
---

<!-- download -->
`;

/** Writes the guide file and returns its path. Refuses an unknown site, a bad slug or language, or an existing file. */
export async function newGuide({ slug, lang, file, translation = file, date = parisToday() }, root = SITES) {
  const problems = [];
  if (!SLUG.test(slug ?? '')) problems.push(`slug "${slug}": the app's slug`);
  if (!LANGS.includes(lang)) problems.push(`lang "${lang}": one of ${LANGS.join(', ')}`);
  if (!SLUG.test(file ?? '')) problems.push(`file-slug "${file}": lowercase letters, digits and hyphens`);
  if (!SLUG.test(translation ?? '')) problems.push(`--translation "${translation}": a slug`);
  if (!DATE.test(date ?? '')) problems.push(`--date "${date}": YYYY-MM-DD`);
  if (problems.length) throw new Error(`new-guide:\n- ${problems.join('\n- ')}`);
  const siteDir = join(root, slug);
  await access(join(siteDir, 'site.json')).catch(() => {
    throw new Error(`new-guide: no site "${slug}" (${join(siteDir, 'site.json')} is missing)`);
  });
  const path = join(siteDir, 'content', lang, 'guides', `${file}.md`);
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, guideTemplate({ translation, date }), { flag: 'wx' }).catch((error) => {
    throw error.code === 'EEXIST' ? new Error(`new-guide: ${path} already exists`) : error;
  });
  return path;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try {
    const { values, positionals } = parseArgs({
      allowPositionals: true,
      options: { translation: { type: 'string' }, date: { type: 'string' } },
    });
    if (positionals.length !== 3) throw new Error('new-guide: <slug> <lang> <file-slug> are required');
    const [slug, lang, file] = positionals;
    const path = await newGuide({ slug, lang, file, ...values });
    console.log(`Wrote ${relative(process.cwd(), path)}: fill its front matter, then the text (GUIDES.md).`);
  } catch (error) {
    console.error(error.message);
    console.error(
      'Usage: npm run new-guide -- <slug> <lang> <file-slug> [--translation <key>] [--date YYYY-MM-DD]',
    );
    process.exit(2);
  }
}

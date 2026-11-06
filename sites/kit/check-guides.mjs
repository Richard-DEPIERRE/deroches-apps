#!/usr/bin/env node
// The daily-guide rules (GUIDES.md), run by `npm test` so CI enforces them: node kit/check-guides.mjs [site dir...]
// (default: every app's site, sites/*/site.json). Every guide has its fact-check issue and dated sources (the build's
// own checks), and each site has at most one new guide per `published` date. It can't read Paperclip: the reviewer
// confirms GATE CE-FACT-CHECK: PASS on the `factCheck` issue before approving a guide PR.
import { access, readdir } from 'node:fs/promises';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadSite } from './lib/config.mjs';
import { loadPages } from './lib/content.mjs';
import { oneGuidePerDay } from './lib/guides.mjs';

const SITES = dirname(dirname(fileURLToPath(import.meta.url)));

const exists = (path) =>
  access(path).then(
    () => true,
    () => false,
  );

/** Every app's site: the folders of `root` (sites/) that have a site.json. */
export async function appSites(root = SITES) {
  const sites = [];
  for (const entry of await readdir(root, { withFileTypes: true })) {
    const dir = join(root, entry.name);
    if (entry.isDirectory() && (await exists(join(dir, 'site.json')))) sites.push(dir);
  }
  return sites.sort();
}

/** One site against the daily-guide rules: its guide count and its problems (none when it passes). */
export async function checkGuides(siteDir) {
  try {
    const pages = await loadPages(siteDir, await loadSite(siteDir));
    return { guides: pages.filter((p) => p.type === 'guide').length, problems: oneGuidePerDay(pages) };
  } catch (error) {
    return { guides: 0, problems: [error.message] };
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const sites = args.length ? args.map((arg) => resolve(arg)) : await appSites();
  if (!sites.length) console.log('check-guides: no app site yet (sites/<slug>/site.json), nothing to check.');
  let failed = false;
  for (const dir of sites) {
    const name = relative(process.cwd(), dir) || '.';
    const { guides, problems } = await checkGuides(dir);
    if (problems.length) {
      failed = true;
      console.error(`check-guides: ${name}:\n- ${problems.join('\n- ')}`);
    } else
      console.log(`check-guides: ${name}: ${guides} guides, at most one new a day, each with its fact-check`);
  }
  if (failed) process.exit(1);
}

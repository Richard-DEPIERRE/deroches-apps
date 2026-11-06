#!/usr/bin/env node
// Builds one app's site: node kit/build.mjs <site dir> [out dir] [--production]   (out dir defaults to <site dir>/dist)
// --production, for a deploy, fails without Richard's complete identity file (sites/legal/identity.json).
import { createHash } from 'node:crypto';
import { mkdir, readFile, realpath, rm, writeFile } from 'node:fs/promises';
import { dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { LANGS, loadSite } from './lib/config.mjs';
import { loadPages } from './lib/content.mjs';
import { fillLegal, IDENTITY_FILE, loadIdentity } from './lib/legal.mjs';
import { notFoundPage, renderPage } from './lib/render.mjs';
import { headers, robots, sitemap } from './lib/seo.mjs';

const KIT = dirname(fileURLToPath(import.meta.url));
const SITES = dirname(KIT);

/** True when `child` is `parent` or inside it. */
function within(parent, child) {
  const rel = relative(parent, child);
  return rel === '' || (rel !== '..' && !rel.startsWith(`..${sep}`) && !isAbsolute(rel));
}

/**
 * The build empties its out dir first, so the out dir must hold nothing else of ours: it is `<site>/dist`, or a folder
 * that is neither inside nor around the site or `sites/` (the kit, Richard's legal file and every other site).
 */
function checkOutDir(siteDir, outDir) {
  if (outDir === join(siteDir, 'dist')) return;
  for (const dir of [siteDir, SITES]) {
    if (within(outDir, dir) || within(dir, outDir)) {
      throw new Error(
        `Refusing to build into ${outDir}: emptying it would delete the site or the kit. ` +
          'Use <site dir>/dist or a folder outside sites/.',
      );
    }
  }
}

/** The site's own accent, appended to the shared stylesheet before hashing (the CSP allows no inline style). */
function accentCss(accent) {
  return (
    `\n/* This site's accent (site.json), added by the build. */\n:root {\n  --accent: ${accent.light};\n}\n` +
    `@media (prefers-color-scheme: dark) {\n  :root {\n    --accent: ${accent.dark};\n  }\n}\n`
  );
}

/** `/assets/<name>.<hash>.<ext>`: a fingerprinted asset path, cached for a year by `_headers`. */
const fingerprint = (name, ext, content) =>
  `/assets/${name}.${createHash('sha256').update(content).digest('hex').slice(0, 10)}.${ext}`;

/**
 * The Worker entry (wrangler.jsonc `main`), with this site's store URLs and page paths embedded. It lives in the out
 * dir, which wrangler uploads as assets, so `.assetsignore` keeps it out of them.
 */
async function workerEntry(outDir, site, pages) {
  // Real paths: Node resolves the import from the entry's real location (macOS's /tmp is a symlink).
  const from = join(await realpath(outDir), '_worker');
  let kit = relative(from, join(await realpath(KIT), 'worker', 'worker.mjs'))
    .split(sep)
    .join('/');
  if (!kit.startsWith('.')) kit = `./${kit}`;
  const config = { slug: site.slug, stores: site.stores ?? {}, paths: pages.map((p) => p.path).sort() };
  return `// Written by kit/build.mjs from site.json: the Worker in front of this site's assets.
import { createWorker } from '${kit}';

export default createWorker(${JSON.stringify(config)});
`;
}

async function emit(outDir, path, content) {
  const file = join(outDir, path);
  await mkdir(dirname(file), { recursive: true });
  await writeFile(file, content);
}

/**
 * Builds the site in `siteDir` into `outDir` and returns what it wrote. A `production` build (a deploy) refuses a
 * missing or incomplete identity file; a review build shows a visible placeholder and keeps the legal notice noindex.
 */
export async function build(siteDir, outDir = join(siteDir, 'dist'), options = {}) {
  const { production = false, identityFile = IDENTITY_FILE } = options;
  siteDir = resolve(siteDir);
  outDir = resolve(outDir);
  checkOutDir(siteDir, outDir);
  const site = await loadSite(siteDir);
  const pages = await loadPages(siteDir, site);
  const identity = await loadIdentity(identityFile, production);
  fillLegal(pages, site, identity);
  await rm(outDir, { recursive: true, force: true });

  const css = (await readFile(join(KIT, 'assets', 'site.css'), 'utf8')) + accentCss(site.accent);
  const stylesheet = fingerprint('site', 'css', css);
  await emit(outDir, stylesheet, css);
  const js = await readFile(join(KIT, 'assets', 'a.js'), 'utf8');
  const script = fingerprint('a', 'js', js);
  await emit(outDir, script, js);

  const ctx = { site, pages, stylesheet, script };
  for (const page of pages) await emit(outDir, `${page.path}index.html`, renderPage(page, ctx));
  for (const lang of LANGS) {
    const page = notFoundPage(lang, site);
    await emit(outDir, page.path, renderPage(page, ctx));
  }
  await emit(outDir, 'sitemap.xml', sitemap(pages));
  await emit(outDir, 'robots.txt', robots(site));
  await emit(outDir, '_headers', headers());
  await emit(outDir, '_worker/index.mjs', await workerEntry(outDir, site, pages));
  await emit(outDir, '.assetsignore', '_worker\n');
  return { site, pages, outDir, identityProblem: identity.problem };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const production = args.includes('--production');
  const [siteArg, outArg, ...rest] = args.filter((arg) => arg !== '--production');
  if (!siteArg || rest.length) {
    console.error('Usage: node kit/build.mjs <site dir> [out dir] [--production]');
    process.exit(2);
  }
  try {
    const { pages, outDir, identityProblem } = await build(resolve(siteArg), outArg && resolve(outArg), {
      production,
    });
    if (identityProblem)
      console.warn(`Review build only (the legal notice is a placeholder): ${identityProblem}`);
    console.log(`Built ${pages.length} pages into ${outDir}`);
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}

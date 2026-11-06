#!/usr/bin/env node
// Builds one app's site: node kit/build.mjs <site dir> [out dir]   (out dir defaults to <site dir>/dist)
import { createHash } from 'node:crypto';
import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { LANGS, loadSite } from './lib/config.mjs';
import { loadPages } from './lib/content.mjs';
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

async function emit(outDir, path, content) {
  const file = join(outDir, path);
  await mkdir(dirname(file), { recursive: true });
  await writeFile(file, content);
}

/** Builds the site in `siteDir` into `outDir` and returns what it wrote. */
export async function build(siteDir, outDir = join(siteDir, 'dist')) {
  siteDir = resolve(siteDir);
  outDir = resolve(outDir);
  checkOutDir(siteDir, outDir);
  const site = await loadSite(siteDir);
  const pages = await loadPages(siteDir, site);
  await rm(outDir, { recursive: true, force: true });

  const css = (await readFile(join(KIT, 'assets', 'site.css'), 'utf8')) + accentCss(site.accent);
  const stylesheet = `/assets/site.${createHash('sha256').update(css).digest('hex').slice(0, 10)}.css`;
  await emit(outDir, stylesheet, css);

  const ctx = { site, pages, stylesheet };
  for (const page of pages) await emit(outDir, `${page.path}index.html`, renderPage(page, ctx));
  for (const lang of LANGS) {
    const page = notFoundPage(lang, site);
    await emit(outDir, page.path, renderPage(page, ctx));
  }
  await emit(outDir, 'sitemap.xml', sitemap(pages));
  await emit(outDir, 'robots.txt', robots(site));
  await emit(outDir, '_headers', headers());
  return { site, pages, outDir };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [siteArg, outArg] = process.argv.slice(2);
  if (!siteArg) {
    console.error('Usage: node kit/build.mjs <site dir> [out dir]');
    process.exit(2);
  }
  try {
    const { pages, outDir } = await build(resolve(siteArg), outArg && resolve(outArg));
    console.log(`Built ${pages.length} pages into ${outDir}`);
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}

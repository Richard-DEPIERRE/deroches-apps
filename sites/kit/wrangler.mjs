#!/usr/bin/env node
// Writes a site's deploy config from the kit template: node kit/wrangler.mjs <site dir> [--check]
// --check fails when <site dir>/wrangler.jsonc is missing or differs from the template (CI runs it for every site).
import { readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadSite } from './lib/config.mjs';

const TEMPLATE = join(dirname(fileURLToPath(import.meta.url)), 'templates', 'wrangler.jsonc');

/** The wrangler.jsonc of a site (its slug and domain filled in). */
export async function wranglerConfig(site) {
  const template = await readFile(TEMPLATE, 'utf8');
  return template.replaceAll('{{slug}}', site.slug).replaceAll('{{domain}}', site.domain);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const check = args.includes('--check');
  const [siteArg, ...rest] = args.filter((arg) => arg !== '--check');
  if (!siteArg || rest.length) {
    console.error('Usage: node kit/wrangler.mjs <site dir> [--check]');
    process.exit(2);
  }
  try {
    const siteDir = resolve(siteArg);
    const file = join(siteDir, 'wrangler.jsonc');
    const expected = await wranglerConfig(await loadSite(siteDir));
    if (!check) {
      await writeFile(file, expected);
      console.log(`Wrote ${file}`);
    } else if ((await readFile(file, 'utf8').catch(() => '')) !== expected) {
      console.error(
        `${file} is missing or differs from the kit template: run node kit/wrangler.mjs ${siteArg}`,
      );
      process.exit(1);
    }
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}

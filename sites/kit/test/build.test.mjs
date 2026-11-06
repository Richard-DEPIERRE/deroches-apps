import assert from 'node:assert/strict';
import { access, cp, mkdtemp, readdir, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { after, before, describe, test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { build } from '../build.mjs';

const FIXTURE = fileURLToPath(new URL('./fixture', import.meta.url));
const SITES = fileURLToPath(new URL('../..', import.meta.url));
const tmp = await mkdtemp(join(tmpdir(), 'site-kit-'));
after(() => rm(tmp, { recursive: true, force: true }));

const read = (out, path) => readFile(join(out, path), 'utf8');
const links = (html, rel) =>
  [...html.matchAll(new RegExp(`<link rel="${rel}"(?: hreflang="([^"]+)")? href="([^"]+)">`, 'g'))].map(
    ([, lang, href]) => (lang ? `${lang} ${href}` : href),
  );

const jsonLd = (html) =>
  [...html.matchAll(/<script type="application\/ld\+json">(.+?)<\/script>/g)].map(([, json]) =>
    JSON.parse(json),
  );

/** A copy of the fixture with `change(dir)` applied, for the failure cases. */
async function variant(name, change) {
  const dir = join(tmp, name);
  await cp(FIXTURE, dir, { recursive: true });
  await change(dir);
  return dir;
}

describe('a built site', () => {
  let out;
  before(async () => {
    out = join(tmp, 'dist');
    await build(FIXTURE, out);
  });

  test('puts French at the root and English under /en/', async () => {
    assert.match(await read(out, 'index.html'), /<html lang="fr">/);
    assert.match(await read(out, 'en/index.html'), /<html lang="en">/);
    assert.match(await read(out, 'a-propos/index.html'), /<h1>À propos<\/h1>/);
    assert.match(await read(out, 'en/about/index.html'), /<h1>About<\/h1>/);
  });

  test('links translations both ways with hreflang and an x-default', async () => {
    const expected = [
      'fr https://exemple.test/a-propos/',
      'en https://exemple.test/en/about/',
      'x-default https://exemple.test/a-propos/',
    ];
    assert.deepEqual(links(await read(out, 'a-propos/index.html'), 'alternate'), expected);
    assert.deepEqual(links(await read(out, 'en/about/index.html'), 'alternate'), expected);
    assert.match(await read(out, 'en/about/index.html'), /<a href="\/a-propos\/" hreflang="fr" lang="fr">/);
  });

  test('gives each page its own canonical URL, and no alternates without a translation', async () => {
    const html = await read(out, 'guides/seulement-en-francais/index.html');
    assert.deepEqual(links(html, 'canonical'), ['https://exemple.test/guides/seulement-en-francais/']);
    assert.deepEqual(links(html, 'alternate'), []);
    assert.match(html, /<a href="\/en\/" hreflang="en" lang="en">/, 'falls back to the English home page');
  });

  test('lists indexable pages in the sitemap with lastmod and alternates', async () => {
    const xml = await read(out, 'sitemap.xml');
    const locs = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map(([, loc]) => loc);
    assert.deepEqual(locs.sort(), [
      'https://exemple.test/',
      'https://exemple.test/a-propos/',
      'https://exemple.test/en/',
      'https://exemple.test/en/about/',
      'https://exemple.test/guides/seulement-en-francais/',
      'https://exemple.test/mentions-legales/',
    ]);
    assert.match(xml, /<loc>https:\/\/exemple\.test\/en\/about\/<\/loc>\n {4}<lastmod>2026-10-31<\/lastmod>/);
    assert.match(xml, /hreflang="x-default" href="https:\/\/exemple\.test\/"/);
  });

  test('keeps noindex pages out of the index and the sitemap', async () => {
    const html = await read(out, 'brouillon/index.html');
    assert.match(html, /<meta name="robots" content="noindex">/);
    assert.deepEqual(links(html, 'canonical'), []);
    assert.doesNotMatch(await read(out, 'sitemap.xml'), /brouillon/);
  });

  test('writes robots.txt, security headers and a not-found page per language', async () => {
    assert.match(await read(out, 'robots.txt'), /^Sitemap: https:\/\/exemple\.test\/sitemap\.xml$/m);
    const headers = await read(out, '_headers');
    assert.match(headers, /form-action 'none'/);
    assert.match(headers, /default-src 'self'/);
    assert.match(await read(out, '404.html'), /Page introuvable/);
    assert.match(await read(out, 'en/404.html'), /Page not found/);
  });

  test('adds WebSite structured data on home pages, and no app offer before launch', async () => {
    const html = await read(out, 'en/index.html');
    const blocks = jsonLd(html);
    assert.deepEqual(
      blocks.map((b) => b['@type']),
      ['WebSite'],
    );
    assert.equal(blocks[0].inLanguage, 'en');
  });

  test('links legal pages from the footer in their own language only, and has no empty footer', async () => {
    assert.match(await read(out, 'index.html'), /<a href="\/mentions-legales\/">Mentions légales<\/a>/);
    const en = await read(out, 'en/index.html');
    assert.doesNotMatch(en, /mentions-legales/);
    assert.doesNotMatch(en, /<footer/, 'no English legal page in the fixture, so no footer');
  });

  test('labels the language switch in the page language', async () => {
    assert.match(await read(out, 'index.html'), /<nav class="lang" aria-label="Langue">/);
    assert.match(await read(out, 'en/index.html'), /<nav class="lang" aria-label="Language">/);
  });

  test("gives the site its own accent, in its own hashed stylesheet and in each scheme's theme colour", async () => {
    const html = await read(out, 'index.html');
    assert.match(html, /<meta name="theme-color" media="\(prefers-color-scheme: light\)" content="#136f63">/);
    assert.match(html, /<meta name="theme-color" media="\(prefers-color-scheme: dark\)" content="#5cc8ad">/);
    const [, href] = html.match(/<link rel="stylesheet" href="([^"]+)">/);
    const css = await read(out, href);
    assert.match(
      css,
      /:root \{\n {2}--accent: #136f63;\n\}\n@media \(prefers-color-scheme: dark\) \{\n {2}:root \{\n {4}--accent: #5cc8ad;/,
    );
    assert.doesNotMatch(css, /#0b57d0|#8ab4f8/, 'no shared accent left in the kit');
  });

  test('loads nothing from another origin, sets no cookie and has no form', async () => {
    const files = (await readdir(out, { recursive: true })).filter((f) => f.endsWith('.html'));
    for (const file of files) {
      const html = await read(out, file);
      assert.doesNotMatch(
        html,
        /<(?:script|link|img|iframe)[^>]+(?:src|href)="(?:https?:)?\/\/(?!exemple\.test)/,
      );
      assert.doesNotMatch(html, /<form|document\.cookie/, file);
    }
  });
});

describe('the build refuses', () => {
  test('a site without its English home page', async () => {
    const dir = await variant('no-en-home', (d) => rm(join(d, 'content/en/index.md')));
    await assert.rejects(build(dir, join(dir, 'dist')), /content\/en\/index\.md is missing/);
  });

  test('a page without a description', async () => {
    const dir = await variant('no-description', (d) =>
      writeFile(join(d, 'content/fr/vide.md'), '---\ntitle: Vide\n---\n# Vide\n'),
    );
    await assert.rejects(build(dir, join(dir, 'dist')), /vide\.md:\n- description is required/);
  });

  test('a file name that is not a URL slug', async () => {
    const dir = await variant('bad-slug', (d) =>
      writeFile(join(d, 'content/fr/Été.md'), '---\ntitle: Été\ndescription: x\n---\n'),
    );
    await assert.rejects(build(dir, join(dir, 'dist')), /"Été" is not a URL slug/);
  });

  test('two pages of one language sharing a translation key', async () => {
    const dir = await variant('dup-translation', (d) =>
      writeFile(
        join(d, 'content/en/about-us.md'),
        '---\ntitle: A\ndescription: x\ntranslation: about\n---\n',
      ),
    );
    await assert.rejects(build(dir, join(dir, 'dist')), /translation "about" is also used by/);
  });

  test('a live site without a store URL', async () => {
    const dir = await variant('live-no-store', async (d) => {
      const site = JSON.parse(await readFile(join(d, 'site.json'), 'utf8'));
      await writeFile(join(d, 'site.json'), JSON.stringify({ ...site, status: 'live' }));
    });
    await assert.rejects(build(dir, join(dir, 'dist')), /a live site needs at least one store URL/);
  });

  test('a site without its own accent', async () => {
    const dir = await variant('no-accent', async (d) => {
      const { accent, ...site } = JSON.parse(await readFile(join(d, 'site.json'), 'utf8'));
      await writeFile(join(d, 'site.json'), JSON.stringify({ ...site, accent: { light: accent.light } }));
    });
    await assert.rejects(build(dir, join(dir, 'dist')), /accent\.dark is required/);
  });

  test('an accent links would be hard to read on, giving the ratio', async () => {
    const dir = await variant('low-contrast', async (d) => {
      const site = JSON.parse(await readFile(join(d, 'site.json'), 'utf8'));
      const accent = { light: '#5cc8ad', dark: '#136f63' };
      await writeFile(join(d, 'site.json'), JSON.stringify({ ...site, accent }));
    });
    await assert.rejects(
      build(dir, join(dir, 'dist')),
      /accent\.light: #5cc8ad on #ffffff is 2\.03:1, under 4\.5:1[\s\S]*accent\.dark: #136f63 on #111113 is 3\.13:1/,
    );
  });

  test('an out dir that would delete the site, another site or the kit', async () => {
    const dir = await variant('out-dir', async () => {});
    for (const outDir of [
      dir,
      dirname(dir),
      join(dir, 'content'),
      SITES,
      join(SITES, 'kit'),
      join(SITES, 'legal'),
    ]) {
      await assert.rejects(build(dir, outDir), /Refusing to build into/, outDir);
    }
    await access(join(dir, 'site.json'));
    await access(join(dir, 'content/fr/index.md'));
    await access(join(SITES, 'kit/build.mjs'));
  });
});

test('a live site offers the app in its structured data', async () => {
  const dir = await variant('live', async (d) => {
    const site = JSON.parse(await readFile(join(d, 'site.json'), 'utf8'));
    const stores = { ios: 'https://apps.apple.com/app/id0', android: null };
    await writeFile(join(d, 'site.json'), JSON.stringify({ ...site, status: 'live', stores }));
  });
  await build(dir, join(dir, 'dist'));
  const html = await read(join(dir, 'dist'), 'index.html');
  const app = jsonLd(html).find((b) => b['@type'] === 'MobileApplication');
  assert.equal(app.operatingSystem, 'iOS');
  assert.deepEqual(app.sameAs, ['https://apps.apple.com/app/id0']);
  assert.equal(app.aggregateRating, undefined, 'never a rating we do not have');
});

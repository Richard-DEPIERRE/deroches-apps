import assert from 'node:assert/strict';
import { access, cp, mkdtemp, readdir, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { after, before, describe, test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { build } from '../build.mjs';

const FIXTURE = fileURLToPath(new URL('./fixture', import.meta.url));
const SITES = fileURLToPath(new URL('../..', import.meta.url));
/** A made-up identity: obviously fake text, never a number that looks real. */
const IDENTITY = fileURLToPath(new URL('./identity.fixture.json', import.meta.url));
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
    await build(FIXTURE, out, { identityFile: IDENTITY });
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
      'https://exemple.test/aide/',
      'https://exemple.test/conditions/',
      'https://exemple.test/confidentialite/',
      'https://exemple.test/en/',
      'https://exemple.test/en/about/',
      'https://exemple.test/en/legal-notice/',
      'https://exemple.test/en/privacy/',
      'https://exemple.test/en/support/',
      'https://exemple.test/en/terms/',
      'https://exemple.test/guides/',
      'https://exemple.test/guides/deuxieme-guide/',
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

  test('links the support page and the legal pages from every footer, in its language and a fixed order', async () => {
    const footerLinks = (html) => [...html.split('<footer')[1].matchAll(/href="([^"]+)"/g)].map(([, h]) => h);
    for (const file of ['index.html', 'guides/seulement-en-francais/index.html', '404.html']) {
      assert.deepEqual(footerLinks(await read(out, file)), [
        '/aide/',
        '/mentions-legales/',
        '/confidentialite/',
        '/conditions/',
      ]);
    }
    for (const file of ['en/index.html', 'en/about/index.html', 'en/404.html']) {
      assert.deepEqual(footerLinks(await read(out, file)), [
        '/en/support/',
        '/en/legal-notice/',
        '/en/privacy/',
        '/en/terms/',
      ]);
    }
  });

  test('pairs each legal page with its translation', async () => {
    assert.deepEqual(links(await read(out, 'en/privacy/index.html'), 'alternate'), [
      'fr https://exemple.test/confidentialite/',
      'en https://exemple.test/en/privacy/',
      'x-default https://exemple.test/confidentialite/',
    ]);
    assert.deepEqual(links(await read(out, 'mentions-legales/index.html'), 'alternate'), [
      'fr https://exemple.test/mentions-legales/',
      'en https://exemple.test/en/legal-notice/',
      'x-default https://exemple.test/mentions-legales/',
    ]);
  });

  test("prints Richard's identity in the legal notice, with labels in the page language", async () => {
    const en = await read(out, 'en/legal-notice/index.html');
    assert.match(
      en,
      /<h2>Publisher<\/h2>\n<dl><dt>Name<\/dt><dd>Test Publisher EI<\/dd><dt>Legal form<\/dt>/,
    );
    assert.match(en, /<dt>Address<\/dt><dd>Test street<br>Test town<\/dd>/);
    assert.match(en, /<dt>Publication director<\/dt><dd>Test Director<\/dd>/);
    assert.match(en, /<h2>Host<\/h2>\n<dl><dt>Name<\/dt><dd>Test Host<\/dd>/);
    assert.doesNotMatch(en, /Share capital|VAT/, 'optional fields left out are not printed');
    assert.match(en, /<a href="mailto:support@exemple\.test">support@exemple\.test<\/a>/);
    const fr = await read(out, 'mentions-legales/index.html');
    assert.match(
      fr,
      /<h1>Mentions légales<\/h1>\n\n<h2>Éditeur du site<\/h2>/,
      "the site's own page, then the identity",
    );
    assert.match(fr, /<dt>Directeur de la publication<\/dt><dd>Test Director<\/dd>/);
    assert.match(fr, /<h2>Hébergeur<\/h2>/);
  });

  test('says in the privacy policy what is true, with the app section from site.json', async () => {
    const fr = await read(out, 'confidentialite/index.html');
    assert.match(fr, /Aucun cookie/);
    assert.match(fr, /sans adresse IP, sans navigateur \(user agent\) et sans aucun identifiant/);
    assert.match(fr, /<h2>Dans l’application<\/h2>\n<p>L&#39;application Exemple garde vos données/);
    assert.match(fr, /Écrivez à <a href="mailto:support@exemple\.test">/);
    assert.match(fr, /href="https:\/\/www\.cnil\.fr\/fr\/plaintes"/);
    const en = await read(out, 'en/privacy/index.html');
    assert.match(en, /<p>The Example app keeps your data on your phone and sends nothing\.<\/p>/);
    assert.match(en, /complain to the CNIL/);
  });

  test('says in the terms that guides are not personal advice and refunds go through the stores', async () => {
    const fr = await read(out, 'conditions/index.html');
    assert.match(fr, /ne\s+remplacent pas un conseil personnalisé/);
    assert.match(fr, /href="https:\/\/reportaproblem\.apple\.com"/);
    const en = await read(out, 'en/terms/index.html');
    assert.match(en, /They are not personal\s+advice/);
    assert.match(en, /governed by the terms of the App Store or Google\s+Play/);
    assert.match(en, /href="https:\/\/support\.google\.com\/googleplay\/answer\/2479637\?hl=en"/);
  });

  test('dates every legal page on its own line under the title', async () => {
    for (const file of ['en/legal-notice/index.html', 'en/privacy/index.html', 'en/terms/index.html']) {
      assert.match(
        await read(out, file),
        /<\/h1>\n<p class="updated">Last updated: 6 November 2026<\/p>\n/,
        file,
      );
    }
    for (const file of ['confidentialite/index.html', 'conditions/index.html']) {
      assert.match(
        await read(out, file),
        /<\/h1>\n<p class="updated">Dernière mise à jour : 6 novembre 2026<\/p>\n/,
        file,
      );
    }
    const own = await read(out, 'mentions-legales/index.html');
    assert.doesNotMatch(own, /class="updated"/, 'the site’s own page has no updated date, so no line');
  });

  test('writes a support page in each language, paired, with the address and no answer-time promise', async () => {
    const expected = [
      'fr https://exemple.test/aide/',
      'en https://exemple.test/en/support/',
      'x-default https://exemple.test/aide/',
    ];
    const fr = await read(out, 'aide/index.html');
    const en = await read(out, 'en/support/index.html');
    assert.deepEqual(links(fr, 'alternate'), expected);
    assert.deepEqual(links(en, 'alternate'), expected);
    assert.match(fr, /<title>Aide et contact \| Exemple<\/title>/);
    assert.match(en, /<title>Help and contact \| Example<\/title>/);
    for (const html of [fr, en]) {
      assert.match(
        html,
        /<p class="contact"><a href="mailto:support@exemple\.test">support@exemple\.test<\/a><\/p>/,
        'the address on a line of its own',
      );
      assert.doesNotMatch(html, / ›/, 'a no-break space before each › keeps it with the word before');
      assert.match(html, /href="https:\/\/reportaproblem\.apple\.com"/);
      assert.match(html, /href="https:\/\/support\.google\.com\/googleplay\/answer\/2479637\?hl=(fr|en)"/);
      assert.doesNotMatch(html, /jour ouvré|working day/, 'no promise until Support confirms it');
      assert.doesNotMatch(html, /<p>\s*<\/p>/, 'no empty paragraph where the promise would be');
    }
    assert.match(fr, /Réglages\u00a0› À propos\u00a0› Contacter l’assistance/);
    assert.match(en, /Settings\u00a0› About\u00a0› Contact support/);
    assert.match(fr, /ouvrez l’app Réglages de l’iPhone/);
    assert.match(en, /open the iPhone’s Settings app/);
    assert.match(fr, /Restaurer les achats/);
    assert.match(fr, /Ce que vous enregistrez dans Exemple reste sur votre téléphone/);
    assert.match(en, /Restore purchases/);
    assert.match(en, /What you save in Example stays on your phone/);
  });

  test('leaves no placeholder in any page', async () => {
    const files = (await readdir(out, { recursive: true })).filter((f) => f.endsWith('.html'));
    for (const file of files) assert.doesNotMatch(await read(out, file), /\{\{/, file);
  });

  test('makes the coming-soon home say what the app does, that it is coming, and link the first guides', async () => {
    const fr = await read(out, 'index.html');
    assert.match(fr, /<p>Exemple fait une seule chose, bien/);
    assert.match(fr, /<p class="coming-soon">Bientôt sur l’App Store et Google Play\.<\/p>/);
    assert.match(
      fr,
      /<h2>Premiers guides<\/h2>\n<ul class="guides"><li><a href="\/guides\/seulement-en-francais\/">Une page sans traduction<\/a><\/li><li><a href="\/guides\/deuxieme-guide\/">/,
    );
    assert.doesNotMatch(fr, /apps\.apple\.com|play\.google\.com|<form|<input/);
    const en = await read(out, 'en/index.html');
    assert.match(en, /<p class="coming-soon">Coming soon to the App Store and Google Play\.<\/p>/);
    assert.doesNotMatch(en, /First guides/, 'no English guide yet, so no empty list');
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

describe("Richard's identity file", () => {
  const MISSING = join(tmp, 'no-identity.json');
  const identityWith = async (name, change) => {
    const data = JSON.parse(await readFile(IDENTITY, 'utf8'));
    change(data);
    const file = join(tmp, name);
    await writeFile(file, JSON.stringify(data));
    return file;
  };

  test('missing, a review build shows a visible placeholder and keeps the legal notice out of search', async () => {
    const out = join(tmp, 'review');
    await build(FIXTURE, out, { identityFile: MISSING });
    for (const [file, text] of [
      ['mentions-legales/index.html', /<p class="identity-missing"><strong>Fichier d’identité manquant/],
      ['en/legal-notice/index.html', /<p class="identity-missing"><strong>Identity file missing/],
    ]) {
      const html = await read(out, file);
      assert.match(html, text);
      assert.match(html, /<meta name="robots" content="noindex">/);
    }
    const xml = await read(out, 'sitemap.xml');
    assert.doesNotMatch(xml, /mentions-legales|legal-notice/);
    assert.match(xml, /confidentialite/, 'the other legal pages stay indexable');
  });

  test('a production build refuses it missing, or with a required field empty, naming fields only', async () => {
    const out = join(tmp, 'prod');
    await assert.rejects(
      build(FIXTURE, out, { production: true, identityFile: MISSING }),
      /no-identity\.json is missing/,
    );
    const empty = await identityWith('empty.json', (d) => {
      d.publisher.registration = ' ';
      delete d.host.phone;
      d.publisher.vatNumber = '';
    });
    await assert.rejects(build(FIXTURE, out, { production: true, identityFile: empty }), (error) => {
      assert.match(
        error.message,
        /missing or empty publisher\.registration, host\.phone, publisher\.vatNumber$/,
      );
      assert.doesNotMatch(error.message, /Test/, 'never prints a value');
      return true;
    });
  });

  test('a production build prints the optional fields when present', async () => {
    const full = await identityWith('full.json', (d) => {
      d.publisher.shareCapital = 'Test capital';
      d.publisher.vatNumber = 'Test VAT';
    });
    const out = join(tmp, 'prod-full');
    await build(FIXTURE, out, { production: true, identityFile: full });
    const html = await read(out, 'mentions-legales/index.html');
    assert.match(html, /<dt>Capital social<\/dt><dd>Test capital<\/dd>/);
    assert.match(html, /<dt>Numéro de TVA intracommunautaire<\/dt><dd>Test VAT<\/dd>/);
    assert.doesNotMatch(html, /noindex/);
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

  test('a coming-soon home page that does not say what the app does', async () => {
    const dir = await variant('thin-home', (d) =>
      writeFile(join(d, 'content/en/index.md'), '---\ntitle: Example\ndescription: x\n---\n# Example\n'),
    );
    await assert.rejects(
      build(dir, join(dir, 'dist')),
      /index\.md: a coming-soon home page says what the app will do/,
    );
  });

  test('a page at the support URL that is not marked as the support page', async () => {
    const dir = await variant('bad-support', (d) =>
      writeFile(join(d, 'content/fr/aide.md'), '---\ntitle: Aide\ndescription: x\ntype: legal\n---\n'),
    );
    await assert.rejects(
      build(dir, join(dir, 'dist')),
      /aide\.md: the support page needs type: page and translation: support/,
    );
  });

  test('a support answer time that is not true or false', async () => {
    const dir = await variant('bad-reply', async (d) => {
      const site = JSON.parse(await readFile(join(d, 'site.json'), 'utf8'));
      await writeFile(join(d, 'site.json'), JSON.stringify({ ...site, replyWithinWorkingDay: 'yes' }));
    });
    await assert.rejects(build(dir, join(dir, 'dist')), /replyWithinWorkingDay: true or false/);
  });

  test('a page at a legal URL that is not marked as that legal page', async () => {
    const dir = await variant('bad-legal', (d) =>
      writeFile(join(d, 'content/en/privacy.md'), '---\ntitle: Privacy\ndescription: x\n---\n'),
    );
    await assert.rejects(
      build(dir, join(dir, 'dist')),
      /privacy\.md: a legal page needs type: legal and translation: privacy/,
    );
  });

  test('a legal page with an unknown placeholder', async () => {
    const dir = await variant('bad-placeholder', (d) =>
      writeFile(
        join(d, 'content/en/terms.md'),
        '---\ntitle: Terms\ndescription: x\ntype: legal\ntranslation: terms\n---\nAs of {{updated}}.\n',
      ),
    );
    await assert.rejects(
      build(dir, join(dir, 'dist')),
      /terms\.md: \{\{updated\}\} is unknown or has no value/,
    );
  });

  test('a site without its support address or what its app collects', async () => {
    const dir = await variant('no-privacy-facts', async (d) => {
      const { supportEmail, appData, ...site } = JSON.parse(await readFile(join(d, 'site.json'), 'utf8'));
      await writeFile(join(d, 'site.json'), JSON.stringify({ ...site, appData: { fr: appData.fr } }));
    });
    await assert.rejects(build(dir, join(dir, 'dist')), /appData\.en is required[\s\S]*supportEmail:/);
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

describe('the support page', () => {
  test('promises an answer within a working day once Support has confirmed it', async () => {
    const dir = await variant('reply', async (d) => {
      const site = JSON.parse(await readFile(join(d, 'site.json'), 'utf8'));
      await writeFile(join(d, 'site.json'), JSON.stringify({ ...site, replyWithinWorkingDay: true }));
    });
    const out = join(tmp, 'reply-dist');
    await build(dir, out, { identityFile: IDENTITY });
    assert.match(
      await read(out, 'aide/index.html'),
      /<p>Nous répondons à chaque e-mail sous un jour ouvré\.<\/p>/,
    );
    assert.match(
      await read(out, 'en/support/index.html'),
      /<p>We answer every email within a working day\.<\/p>/,
    );
  });

  test("can be the site's own page, with the kit's placeholders filled", async () => {
    const dir = await variant('own-support', (d) =>
      writeFile(
        join(d, 'content/en/support.md'),
        '---\ntitle: Support\ndescription: x\ntranslation: support\n---\n# Support\n\nMail {{support}} about {{name}}.\n',
      ),
    );
    const out = join(tmp, 'own-support-dist');
    await build(dir, out, { identityFile: IDENTITY });
    const html = await read(out, 'en/support/index.html');
    assert.match(
      html,
      /<p>Mail <a href="mailto:support@exemple\.test">support@exemple\.test<\/a> about Example\.<\/p>/,
    );
    assert.doesNotMatch(html, /Restore purchases/, 'the kit text is replaced');
    assert.match(
      await read(out, 'aide/index.html'),
      /Restaurer les achats/,
      'the other language keeps the kit text',
    );
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
  assert.doesNotMatch(html, /coming-soon|Premiers guides/, "a live home page is the site's own text");
});

const GUIDE = 'guides/seulement-en-francais/index.html';
/** The fixture as a live site, with an App Store URL only. */
const goLive = async (d) => {
  const site = JSON.parse(await readFile(join(d, 'site.json'), 'utf8'));
  const stores = { ios: 'https://apps.apple.com/app/id0', android: null };
  await writeFile(join(d, 'site.json'), JSON.stringify({ ...site, status: 'live', stores }));
};
/** Writes a French guide (front matter lines, then body) into a copy of the fixture. */
const guide =
  (lines, body = 'Texte.') =>
  (d) =>
    writeFile(join(d, 'content/fr/guides/test.md'), `---\n${lines.join('\n')}\n---\n${body}\n`);
const VALID = [
  'title: T',
  'description: D',
  'type: guide',
  'published: 2026-11-05',
  'factCheck: DAPP-3',
  'sources: [{title: S, publisher: P, url: "https://www.impots.gouv.fr/", source_date: 2026-01-01, read: 2026-11-04}]',
];

describe('a guide', () => {
  let out;
  before(async () => {
    out = join(tmp, 'dist-guides');
    await build(FIXTURE, out, { identityFile: IDENTITY });
  });

  test('takes its H1 from the title and shows when it was published and updated', async () => {
    const html = await read(out, GUIDE);
    assert.match(
      html,
      /<\/nav>\n<h1>Une page sans traduction<\/h1>\n<p class="updated">Publié le <time datetime="2026-11-02">2 novembre 2026<\/time> · mis à jour le <time datetime="2026-11-04">/,
    );
    assert.match(
      html,
      /<a href="\/">Accueil<\/a> <span aria-hidden="true">›<\/span> <a href="\/guides\/">Guides<\/a><\/nav>/,
    );
  });

  test('puts a download block at the marker and the app banner at the end, saying "coming soon" before launch', async () => {
    const html = await read(out, GUIDE);
    assert.match(
      html,
      /<aside class="download"><p>Exemple fait ce calcul pour vous, sur votre téléphone\.<\/p><p class="coming-soon">/,
    );
    assert.match(
      html,
      /<aside class="app-banner" aria-label="Exemple"><p><strong>Exemple<\/strong> — L&#39;appli qui sert/,
    );
    assert.doesNotMatch(html, /\/go\/|<!-- download/, 'no store link before launch');
  });

  test('lists its dated sources, then its related guides', async () => {
    const html = await read(out, GUIDE);
    assert.match(
      html,
      /<h2 id="sources">Sources<\/h2><ol><li><a href="https:\/\/www\.service-public\.fr\/particuliers\/vosdroits\/F1">Une page officielle<\/a>, Un service public, <time datetime="2026-01-01">1er janvier 2026<\/time> \(consulté le <time datetime="2026-11-01">1er novembre 2026<\/time>\)/,
    );
    assert.match(
      html,
      /<h2 id="related">À lire aussi<\/h2><ul><li><a href="\/guides\/deuxieme-guide\/">Un deuxième guide<\/a>/,
    );
  });

  test('scrolls a wide table in its own box', async () => {
    assert.match(
      await read(out, GUIDE),
      /<div class="table-scroll" tabindex="0"><table>[\s\S]*<\/table><\/div>/,
    );
  });

  test('is an Article published by the site, with its breadcrumb', async () => {
    const [article, crumbs] = jsonLd(await read(out, GUIDE));
    assert.equal(article['@type'], 'Article');
    assert.equal(article.datePublished, '2026-11-02');
    assert.equal(article.dateModified, '2026-11-04');
    assert.equal(article.inLanguage, 'fr');
    assert.deepEqual(article.publisher, {
      '@type': 'Organization',
      name: 'Exemple',
      url: 'https://exemple.test/',
    });
    assert.equal(article.author, undefined, 'no invented author');
    assert.deepEqual(
      crumbs.itemListElement.map((c) => c.item),
      [
        'https://exemple.test/',
        'https://exemple.test/guides/',
        `https://exemple.test/${GUIDE.replace('index.html', '')}`,
      ],
    );
  });

  test('is listed on its hub, newest first; a hub without guides stays out of search and the header', async () => {
    const hub = await read(out, 'guides/index.html');
    assert.match(
      hub,
      /<ul class="guide-list"><li><a href="\/guides\/seulement-en-francais\/">.*<li><a href="\/guides\/deuxieme-guide\/">/,
    );
    assert.match(hub, /<a class="nav" href="\/guides\/" aria-current="page">Guides<\/a>/);
    assert.match(hub, /<meta name="description" content="Exemple\u00a0: tous les guides, du plus récent/);
    assert.match(
      await read(out, GUIDE),
      /<a class="nav" href="\/guides\/">Guides<\/a>/,
      'current only on the hub',
    );
    const en = await read(out, 'en/guides/index.html');
    assert.match(en, /<meta name="robots" content="noindex">/);
    assert.doesNotMatch(en, /class="nav"/);
  });
});

test('a live site links each store it is on through the counted redirect, in guides and on the home page', async () => {
  const dir = await variant('live-guides', goLive);
  await build(dir, join(dir, 'dist'));
  const html = await read(join(dir, 'dist'), GUIDE);
  const button =
    '<p class="store-buttons"><a class="store-button" href="/go/ios?from=%2Fguides%2Fseulement-en-francais%2F" rel="nofollow">Télécharger sur l’App Store</a></p>';
  assert.equal(html.split(button).length - 1, 2, 'at the marker and in the banner');
  assert.doesNotMatch(html, /\/go\/android|apps\.apple\.com|coming-soon/);
  assert.match(
    await read(join(dir, 'dist'), 'en/index.html'),
    /href="\/go\/ios\?from=%2Fen%2F" rel="nofollow">Download from the App Store</,
  );
});

describe('the build refuses a guide', () => {
  const refuses = async (name, change, error) => {
    const dir = await variant(name, change);
    await assert.rejects(build(dir, join(dir, 'dist'), { otherDomains: ['autre-appli.fr'] }), error);
  };
  test('(none of the below: a complete guide builds)', async () => {
    const dir = await variant('guide-ok', guide(VALID));
    await build(dir, join(dir, 'dist'));
  });
  test('without its publish date, its fact-check issue or its sources', () =>
    refuses(
      'guide-bare',
      guide(VALID.slice(0, 3)),
      /published: YYYY-MM-DD[\s\S]*factCheck: DAPP-<n>[\s\S]*sources: at least one/,
    ));
  test('with an undated source', () =>
    refuses(
      'guide-source',
      guide([...VALID.slice(0, 5), 'sources: [{title: S, publisher: P, url: "https://x.fr/"}]']),
      /sources\[0\]\.source_date[\s\S]*sources\[0\]\.read/,
    ));
  test('with its own # heading', () => refuses('guide-h1', guide(VALID, '# Titre'), /its H1 is the title/));
  test('relating to a guide that does not exist', () =>
    refuses('guide-related', guide([...VALID, 'related: [nope]']), /related "nope" is not another guide/));
});

describe('the build refuses Markdown with', () => {
  const refuses = async (name, body, error) => {
    const dir = await variant(name, guide(VALID, body));
    await assert.rejects(build(dir, join(dir, 'dist'), { otherDomains: ['autre-appli.fr'] }), error);
  };
  for (const tag of ['script', 'iframe', 'form'])
    test(`a raw <${tag}>`, () =>
      refuses(`raw-${tag}`, `<${tag}></${tag}>`, new RegExp(`raw <${tag}> is not allowed`)));
  test('a link to another origin, even a store', () =>
    refuses(
      'foreign-href',
      '[App](https://apps.apple.com/app/id0)',
      /href="https:\/\/apps\.apple\.com\/app\/id0" points to another origin/,
    ));
  test('an image or srcset from another origin', () =>
    refuses(
      'foreign-src',
      '<img src="https://cdn.test/a.png" srcset="/a.png 1x, https://cdn.test/b.png 2x" alt="">',
      /src="https:\/\/cdn\.test\/a\.png"[\s\S]*srcset="https:\/\/cdn\.test\/b\.png"/,
    ));
  test('a link to no page of the site', () =>
    refuses(
      'broken-link',
      '[Perdu](/guides/perdu/)',
      /Link check failed:\n- \/guides\/test\/: href="\/guides\/perdu\/" goes to no page/,
    ));
  test("a source on another studio app's site", async () => {
    const source =
      'sources: [{title: S, publisher: P, url: "https://www.autre-appli.fr/x", source_date: 2026, read: 2026-11-04}]';
    const dir = await variant('studio-link', guide([...VALID.slice(0, 5), source]));
    await assert.rejects(
      build(dir, join(dir, 'dist'), { otherDomains: ['autre-appli.fr'] }),
      /href="https:\/\/www\.autre-appli\.fr\/x" links to another studio app's site/,
    );
  });
});

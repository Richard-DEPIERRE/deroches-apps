import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { cp, mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { after, describe, test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { appSites, checkGuides } from '../check-guides.mjs';
import { parseFrontMatter } from '../lib/content.mjs';
import { newGuide, parisToday } from '../new-guide.mjs';

const FIXTURE = fileURLToPath(new URL('./fixture', import.meta.url));
const CHECK = fileURLToPath(new URL('../check-guides.mjs', import.meta.url));
const tmp = await mkdtemp(join(tmpdir(), 'site-kit-guides-'));
after(() => rm(tmp, { recursive: true, force: true }));

/** A sites/ folder holding a copy of the fixture as the site `exemple`, with `change(siteDir)` applied. */
async function sites(name, change = async () => {}) {
  const root = join(tmp, name);
  await cp(FIXTURE, join(root, 'exemple'), { recursive: true });
  await change(join(root, 'exemple'));
  return root;
}

/** A complete guide: `published` on `day`, translation key `key`. */
async function guide(dir, lang, file, key, day, extra = '') {
  await mkdir(join(dir, 'content', lang, 'guides'), { recursive: true });
  await writeFile(
    join(dir, 'content', lang, 'guides', `${file}.md`),
    `---\ntitle: T\ndescription: D\ntype: guide\ntranslation: ${key}\npublished: ${day}\n${extra}factCheck: DAPP-9\n` +
      'sources: [{title: S, publisher: P, url: "https://www.service-public.fr/", source_date: 2026-01-01, read: 2026-11-04}]\n' +
      '---\nTexte.\n',
  );
}

describe('check-guides', () => {
  test('passes the fixture: one guide per published date, each fact-checked', async () => {
    assert.deepEqual(await checkGuides(FIXTURE), { guides: 2, problems: [] });
  });

  test('refuses two new guides published on the same day', async () => {
    const root = await sites('two-a-day', (d) => guide(d, 'fr', 'autre', 'autre', '2026-11-02'));
    const { problems } = await checkGuides(join(root, 'exemple'));
    assert.equal(problems.length, 1);
    assert.match(problems[0], /published 2026-11-02: 2 new guides, at most one a day per site/);
    assert.match(problems[0], /autre\.md, .*seulement-en-francais\.md/);
  });

  test("counts a guide's French and English pages as one guide", async () => {
    const root = await sites('fr-en', (d) =>
      guide(d, 'en', 'only-in-french', 'seulement-en-francais', '2026-11-02'),
    );
    assert.deepEqual((await checkGuides(join(root, 'exemple'))).problems, []);
  });

  test('counts a translation published on a later day against that day', async () => {
    const root = await sites('late-translation', async (d) => {
      await guide(d, 'en', 'second', 'deuxieme-guide', '2026-11-02');
    });
    assert.match(
      (await checkGuides(join(root, 'exemple'))).problems[0],
      /published 2026-11-02: 2 new guides/,
    );
  });

  test('does not count a correction (same published, later updated) as a new guide', async () => {
    const root = await sites('correction', async (d) => {
      await guide(d, 'fr', 'nouveau', 'nouveau', '2026-11-06');
      await guide(d, 'fr', 'deuxieme-guide', 'deuxieme-guide', '2026-10-20', 'updated: 2026-11-06\n');
    });
    assert.deepEqual(await checkGuides(join(root, 'exemple')), { guides: 3, problems: [] });
  });

  test('refuses a guide without its fact-check issue or a dated source', async () => {
    const root = await sites('no-fact-check', (d) =>
      writeFile(
        join(d, 'content/fr/guides/sans-verif.md'),
        '---\ntitle: T\ndescription: D\ntype: guide\npublished: 2026-11-06\nsources: [{title: S, publisher: P, url: "https://x.fr/"}]\n---\nTexte.\n',
      ),
    );
    const [problem] = (await checkGuides(join(root, 'exemple'))).problems;
    assert.match(problem, /factCheck: DAPP-<n>/);
    assert.match(problem, /sources\[0\]\.source_date[\s\S]*sources\[0\]\.read/);
  });

  test('finds every app site, and the command fails on a site that breaks a rule', async () => {
    const root = await sites('cli', (d) => guide(d, 'fr', 'autre', 'autre', '2026-10-20'));
    assert.deepEqual(await appSites(root), [join(root, 'exemple')]);
    await assert.rejects(promisify(execFile)(process.execPath, [CHECK, join(root, 'exemple')]), (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /published 2026-10-20: 2 new guides/);
      return true;
    });
    const ok = await promisify(execFile)(process.execPath, [CHECK, FIXTURE]);
    assert.match(ok.stdout, /2 guides, at most one new a day/);
  });
});

describe('new-guide', () => {
  test('writes the guide with its front matter to fill, refused by the check until filled', async () => {
    const root = await sites('new');
    const path = await newGuide(
      {
        slug: 'exemple',
        lang: 'en',
        file: 'second-guide',
        translation: 'deuxieme-guide',
        date: '2026-11-07',
      },
      root,
    );
    assert.equal(path, join(root, 'exemple/content/en/guides/second-guide.md'));
    const source = await readFile(path, 'utf8');
    const { data, body } = parseFrontMatter(source, path);
    assert.deepEqual(data, {
      title: '',
      description: '',
      translation: 'deuxieme-guide',
      type: 'guide',
      published: '2026-11-07',
      updated: '2026-11-07',
      factCheck: '',
      sources: [],
    });
    assert.match(body, /<!-- download -->/);
    assert.match((await checkGuides(join(root, 'exemple'))).problems[0], /title is required/);

    const filled = source
      .replace("title: ''", 'title: A second guide')
      .replace("description: ''", 'description: The English page of the second guide.')
      .replace("factCheck: ''", 'factCheck: DAPP-12')
      .replace(
        'sources: []',
        'sources: [{title: S, publisher: P, url: "https://www.gov.uk/", source_date: 2026-01-01, read: 2026-11-06}]',
      );
    await writeFile(path, filled);
    assert.deepEqual((await checkGuides(join(root, 'exemple'))).problems, []);
  });

  test('defaults the translation key to the file slug and the date to today in Paris', async () => {
    const root = await sites('defaults');
    const path = await newGuide({ slug: 'exemple', lang: 'fr', file: 'nouveau' }, root);
    const { data } = parseFrontMatter(await readFile(path, 'utf8'), path);
    assert.equal(data.translation, 'nouveau');
    assert.equal(data.published, parisToday());
    assert.equal(parisToday(new Date('2026-11-06T23:30:00Z')), '2026-11-07');
  });

  test('refuses an existing file, an unknown site and bad arguments', async () => {
    const root = await sites('refuses');
    await assert.rejects(
      newGuide({ slug: 'exemple', lang: 'fr', file: 'deuxieme-guide' }, root),
      /already exists/,
    );
    await assert.rejects(newGuide({ slug: 'absent', lang: 'fr', file: 'x' }, root), /no site "absent"/);
    await assert.rejects(
      newGuide({ slug: 'exemple', lang: 'de', file: 'Mauvais_Nom', date: '6/11/2026' }, root),
      /lang "de"[\s\S]*file-slug "Mauvais_Nom"[\s\S]*--date "6\/11\/2026"/,
    );
  });
});

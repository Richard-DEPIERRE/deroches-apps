import { readdir, readFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';

/** Raw HTML a page's Markdown may never carry: the sites run no third-party code, embed nothing and have no forms. */
const BANNED_TAGS = /<(form|iframe|script|object|embed|style)\b/gi;
/** An opening tag, quoted values included, so text such as `&lt;a href="x"&gt;` in code is never read as a link. */
const TAG = /<[a-z][a-z0-9-]*(?:\s+[^\s"'>/=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'>]+))?)*\s*\/?>/gi;
const ATTRIBUTE = /\s(href|src|srcset)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/gi;

/** Every href, src and srcset URL in the tags of some HTML, as [attribute, url] pairs (srcset split into its URLs). */
function urls(html) {
  const attributes = [...html.matchAll(TAG)].flatMap(([tag]) => [...tag.matchAll(ATTRIBUTE)]);
  return attributes.flatMap(([, name, ...values]) => {
    const value = values.find((v) => v !== undefined).replaceAll('&amp;', '&');
    const list =
      name.toLowerCase() === 'srcset' ? value.split(',').map((s) => s.trim().split(/\s+/)[0]) : [value];
    return list.filter(Boolean).map((url) => [name.toLowerCase(), url]);
  });
}

const host = (url, base) => {
  try {
    return new URL(url, base);
  } catch {
    return null;
  }
};

/**
 * Problems in the HTML a page's Markdown became. Any page: no form, frame, script, object, embed or style tag, and
 * nothing loaded (src, srcset) from another origin. A site's own pages also link nowhere else (href): a guide's
 * outbound links are its sources, listed by the kit; store links go through /go/<store>, which the kit writes.
 */
export function markdownProblems(html, page, site, { ownContent }) {
  const problems = [...html.matchAll(BANNED_TAGS)].map(
    ([, tag]) => `raw <${tag.toLowerCase()}> is not allowed`,
  );
  for (const [name, url] of urls(html)) {
    const target = host(url, page.url);
    if (target?.protocol === 'mailto:' && name === 'href') continue;
    const foreign = !target || target.origin !== site.origin;
    if (foreign && (name !== 'href' || ownContent))
      problems.push(
        `${name}="${url}" points to another origin (sources go in the front matter's sources list)`,
      );
  }
  return problems;
}

/** The domains of the studio's other sites (`sites/*\/site.json`): a site never links to them. */
export async function studioDomains(sitesDir, siteDir, site) {
  const domains = [];
  for (const entry of await readdir(sitesDir, { withFileTypes: true })) {
    const dir = join(sitesDir, entry.name);
    if (!entry.isDirectory() || resolve(dir) === resolve(siteDir)) continue;
    try {
      const { domain } = JSON.parse(await readFile(join(dir, 'site.json'), 'utf8'));
      if (typeof domain === 'string' && domain !== site.domain) domains.push(domain);
    } catch (error) {
      if (error.code !== 'ENOENT') throw new Error(`${dir}/site.json: ${error.message}`);
    }
  }
  return domains;
}

/**
 * The build's link check, over every file it is about to write (path -> content). Each internal link resolves to a
 * built page or asset (or the store redirects /go/ios and /go/android); none goes to another studio app's domain.
 * Returns the problems, one line each.
 */
export function linkProblems(files, site, otherDomains) {
  const targets = new Set(['/go/ios', '/go/android']);
  for (const path of files.keys())
    targets.add(path.endsWith('/index.html') ? path.slice(0, -'index.html'.length) : path);
  const problems = [];
  for (const [path, content] of files) {
    if (!path.endsWith('.html')) continue;
    const page = path.replace(/index\.html$/, '');
    for (const [name, url] of urls(content)) {
      const target = host(url, `${site.origin}${page}`);
      const where = `${page}: ${name}="${url}"`;
      if (!target || !['https:', 'http:', 'mailto:', 'tel:'].includes(target.protocol)) {
        problems.push(`${where} is not a web, mailto or tel link`);
      } else if (target.origin === site.origin) {
        if (!targets.has(target.pathname) && !targets.has(`${target.pathname}/`))
          problems.push(`${where} goes to no page or file of this site`);
      } else if (otherDomains.some((d) => target.hostname === d || target.hostname.endsWith(`.${d}`))) {
        problems.push(`${where} links to another studio app's site (sites don't promote each other)`);
      }
    }
  }
  return problems;
}

#!/usr/bin/env node
// Post-process the mdBook output: set per-page canonical/Open Graph URLs and
// generate sitemap.xml so Google and Bing can discover every chapter.

import { readdir, readFile, stat, writeFile } from 'node:fs/promises';
import { join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const BASE_URL = 'https://neurono-ml.github.io/sciencekit-go/';
const BOOK_DIR = fileURLToPath(new URL('../book', import.meta.url));
const SKIPPED_PAGES = new Set(['print.html', '404.html', 'toc.html']);
const VERIFICATION_FILE = /^google[0-9a-f]+\.html$/i;

async function listHtmlFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await listHtmlFiles(path)));
    } else if (entry.name.endsWith('.html')) {
      files.push(path);
    }
  }
  return files;
}

function pageUrl(file) {
  const relativePath = relative(BOOK_DIR, file).split(sep).join('/');
  // GitHub Pages serves index.html at the directory URL; keep the canonical
  // form without the file name so both spellings collapse to one URL.
  const canonicalPath = relativePath.replace(/(^|\/)index\.html$/, '$1');
  return BASE_URL + canonicalPath;
}

function escapeXml(value) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}

function injectMetadata(html, url) {
  const canonicalTag = `<link rel="canonical" href="${url}">`;
  const ogUrlTag = `<meta property="og:url" content="${url}">`;

  let updated = html;
  const hasCanonical = /<link\s+rel="canonical"\s+href="[^"]*">/i.test(updated);
  const hasOgUrl = /<meta\s+property="og:url"\s+content="[^"]*">/i.test(updated);

  if (hasCanonical) {
    updated = updated.replace(/<link\s+rel="canonical"\s+href="[^"]*">/i, canonicalTag);
  }
  if (hasOgUrl) {
    updated = updated.replace(/<meta\s+property="og:url"\s+content="[^"]*">/i, ogUrlTag);
  }

  const missingTags = [];
  if (!hasCanonical) missingTags.push(canonicalTag);
  if (!hasOgUrl) missingTags.push(ogUrlTag);
  if (missingTags.length > 0) {
    updated = updated.replace('</head>', `        ${missingTags.join('\n        ')}\n    </head>`);
  }
  return updated;
}

const files = (await listHtmlFiles(BOOK_DIR)).filter((file) => {
  const name = file.split(sep).pop();
  return !SKIPPED_PAGES.has(name) && !VERIFICATION_FILE.test(name);
});

const urls = [];
for (const file of files) {
  const url = pageUrl(file);
  const html = await readFile(file, 'utf8');
  const updated = injectMetadata(html, url);
  if (updated !== html) await writeFile(file, updated);
  const { mtime } = await stat(file);
  urls.push({ loc: url, lastmod: mtime.toISOString().slice(0, 10) });
}

urls.sort((left, right) => left.loc.localeCompare(right.loc));

const sitemap = [
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
  ...urls.map(
    ({ loc, lastmod }) =>
      `  <url><loc>${escapeXml(loc)}</loc><lastmod>${lastmod}</lastmod></url>`
  ),
  '</urlset>',
  ''
].join('\n');

await writeFile(join(BOOK_DIR, 'sitemap.xml'), sitemap);
console.log(`postbuild: ${urls.length} pages indexed in sitemap.xml`);

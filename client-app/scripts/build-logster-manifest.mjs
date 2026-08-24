#!/usr/bin/env node

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { basename, dirname, resolve } from "node:path";
import { pathToFileURL } from "node:url";

function attribute(tag, name) {
  return tag.match(new RegExp(`\\b${name}="([^"]*)"`))?.[1];
}

function assetName(url) {
  return basename(new URL(url, "https://logster.invalid").pathname);
}

export function buildManifest(html) {
  const scriptTags = [...html.matchAll(/<script\b[^>]*>/g)].map((match) => match[0]);
  const linkTags = [...html.matchAll(/<link\b[^>]*>/g)].map((match) => match[0]);
  const metaTags = [...html.matchAll(/<meta\b[^>]*>/g)].map((match) => match[0]);
  const javascript = scriptTags
    .map((tag) => attribute(tag, "src"))
    .filter(Boolean)
    .map(assetName)
    .filter((name) => !name.endsWith("ember-cli-live-reload.js"));
  const stylesheets = linkTags
    .filter((tag) => attribute(tag, "rel")?.split(/\s+/).includes("stylesheet"))
    .map((tag) => attribute(tag, "href"))
    .filter(Boolean)
    .map(assetName);
  const configTag = metaTags.find(
    (tag) => attribute(tag, "name") === "client-app/config/environment"
  );
  const encodedConfig = configTag && attribute(configTag, "content");

  for (const expected of ["vendor.js", "client-app.js"]) {
    if (!javascript.includes(expected)) {
      throw new Error(`The Ember build did not emit ${expected}`);
    }
  }
  for (const expected of ["vendor.css", "client-app.css"]) {
    if (!stylesheets.includes(expected)) {
      throw new Error(`The Ember build did not emit required stylesheets (${expected})`);
    }
  }
  if (!encodedConfig) {
    throw new Error("The Ember build did not emit application environment metadata");
  }

  return {
    javascript,
    stylesheets,
    config: JSON.parse(decodeURIComponent(encodedConfig)),
  };
}

function main() {
  const [indexPath, outputPath] = process.argv.slice(2);
  if (!indexPath || !outputPath) {
    throw new Error("Usage: build-logster-manifest.mjs INDEX_HTML OUTPUT_JSON");
  }

  const html = readFileSync(resolve(indexPath), "utf8");
  const manifest = buildManifest(html);
  const assetsDirectory = resolve(dirname(indexPath), "assets");
  for (const name of [...manifest.javascript, ...manifest.stylesheets]) {
    if (!existsSync(resolve(assetsDirectory, name))) {
      throw new Error(`The Ember build references a missing asset (${name})`);
    }
  }
  writeFileSync(resolve(outputPath), `${JSON.stringify(manifest, null, 2)}\n`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}

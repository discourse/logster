#!/usr/bin/env node

import { readFileSync, writeFileSync } from "node:fs";
import { basename, resolve } from "node:path";

const [indexPath, outputPath] = process.argv.slice(2);
if (!indexPath || !outputPath) {
  throw new Error("Usage: build-logster-manifest.mjs INDEX_HTML OUTPUT_JSON");
}

const html = readFileSync(resolve(indexPath), "utf8");
const javascript = [...html.matchAll(/<script\b[^>]*\bsrc="([^"]+\.js)"[^>]*>/g)]
  .map((match) => basename(new URL(match[1], "https://logster.invalid").pathname))
  .filter((name) => name !== "ember-cli-live-reload.js");
const stylesheets = [
  ...html.matchAll(/<link\b[^>]*\brel="stylesheet"[^>]*\bhref="([^"]+\.css)"[^>]*>/g),
].map((match) => basename(new URL(match[1], "https://logster.invalid").pathname));
const configMatch = html.match(
  /<meta\b[^>]*\bname="client-app\/config\/environment"[^>]*\bcontent="([^"]+)"[^>]*>/
);

if (!javascript.includes("vendor.js") || !javascript.includes("client-app.js")) {
  throw new Error("The Ember build did not emit the expected application scripts");
}
if (!configMatch) {
  throw new Error("The Ember build did not emit application environment metadata");
}

const config = JSON.parse(decodeURIComponent(configMatch[1]));
writeFileSync(
  resolve(outputPath),
  `${JSON.stringify({ javascript, stylesheets, config }, null, 2)}\n`
);

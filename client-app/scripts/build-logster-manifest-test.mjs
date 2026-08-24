import test from "node:test";
import assert from "node:assert/strict";
import { buildManifest } from "./build-logster-manifest.mjs";

const config = encodeURIComponent(
  JSON.stringify({
    modulePrefix: "client-app",
    environment: "production",
    rootURL: "/logs/",
    EmberENV: {},
    APP: {},
  })
);

function html({ styles = true, liveReload = false } = {}) {
  return `<!doctype html>
    <html>
      <head>
        ${
          styles
            ? '<link href="/logs/assets/vendor.css" rel="stylesheet"><link href="/logs/assets/client-app.css" rel="stylesheet">'
            : ""
        }
        <meta name="client-app/config/environment" content="${config}">
        ${liveReload ? '<script src="/logsember-cli-live-reload.js"></script>' : ""}
        <script src="/logs/assets/vendor.js"></script>
        <script src="/logs/assets/chunk.application.js"></script>
        <script src="/logs/assets/client-app.js"></script>
      </head>
    </html>`;
}

test("extracts ordered scripts and styles regardless of attribute order", function () {
  const manifest = buildManifest(html());

  assert.deepEqual(manifest.javascript, [
    "vendor.js",
    "chunk.application.js",
    "client-app.js",
  ]);
  assert.deepEqual(manifest.stylesheets, ["vendor.css", "client-app.css"]);
  assert.equal(manifest.config.modulePrefix, "client-app");
});

test("rejects a build without required stylesheets", function () {
  assert.throws(() => buildManifest(html({ styles: false })), /stylesheets/);
});

test("excludes live reload scripts by suffix", function () {
  const manifest = buildManifest(html({ liveReload: true }));

  assert.equal(
    manifest.javascript.some((name) => name.endsWith("ember-cli-live-reload.js")),
    false
  );
});

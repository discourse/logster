import { createRequire } from "node:module";
import { extname } from "node:path";
import { defineConfig } from "vite";
import { extensions, classicEmberSupport, ember } from "@embroider/vite";
import { babel } from "@rollup/plugin-babel";

const require = createRequire(import.meta.url);
const Project = require("ember-cli/lib/models/project");

function emitClientConfig() {
  return {
    name: "logster-client-config",
    apply: "build",
    generateBundle() {
      this.emitFile({
        type: "asset",
        fileName: "logster-config.json",
        source: `${JSON.stringify(Project.closestSync(import.meta.dirname).config("production"), null, 2)}\n`,
      });
    },
  };
}

const BACKEND = { target: process.env.LOGSTER_BACKEND || "http://127.0.0.1:9292" };

function appRoute(request) {
  const reads = request.method === "GET" || request.method === "HEAD";
  return reads && !extname(request.url.split("?")[0]);
}

export default defineConfig({
  build: {
    manifest: true,
  },
  server: {
    proxy: {
      // Generates sample log data, so it is the backend's even in a browser.
      "^/report_error": BACKEND,
      "^/logs(?:/|$)": {
        ...BACKEND,
        bypass: (request) => (appRoute(request) ? "/index.html" : undefined),
      },
    },
  },
  plugins: [
    emitClientConfig(),
    classicEmberSupport(),
    ember(),
    babel({
      babelHelpers: "runtime",
      extensions,
    }),
  ],
});

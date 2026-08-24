"use strict";

const EmberApp = require("ember-cli/lib/broccoli/ember-app");

const {
  compatBuild
} = require("@embroider/compat");

module.exports = async function(defaults) {
  const {
    buildOnce
  } = await import("@embroider/vite");

  const app = new EmberApp(defaults, {
    autoImport: {
      webpack: {
        output: {
          chunkFilename: "chunk.[id].[contenthash].js",
          filename: "chunk.[name].[contenthash].js",
        },
      },
    },
    fingerprint: {
      enabled: false,
    },
  });

  return compatBuild(app, buildOnce);
};

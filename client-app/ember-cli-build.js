"use strict";

const EmberApp = require("ember-cli/lib/broccoli/ember-app");

module.exports = function (defaults) {
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

  return app.toTree();
};

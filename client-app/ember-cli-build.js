"use strict";

const EmberApp = require("ember-cli/lib/broccoli/ember-app");

module.exports = function (defaults) {
  const app = new EmberApp(defaults, {
    fingerprint: {
      enabled: false,
    },
  });

  app.import("node_modules/moment/min/moment.min.js");
  return app.toTree();
};

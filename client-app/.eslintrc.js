"use strict";

module.exports = {
  root: true,
  parser: "babel-eslint",
  parserOptions: {
    ecmaVersion: 2018,
    sourceType: "module",
    ecmaFeatures: {
      legacyDecorators: true,
    },
  },
  plugins: ["ember"],
  extends: [
    "eslint:recommended",
    "plugin:ember/recommended",
    "plugin:prettier/recommended",
  ],
  env: {
    browser: true,
  },
  globals: {
    Em: false,
    moment: false,
  },
  rules: {
    // Temporarily disable some newer rules
    "ember/no-actions-hash": "off",
    "ember/no-classic-classes": "off",
    "ember/no-classic-components": "off",
    "ember/no-component-lifecycle-hooks": "off",
    "ember/no-get": "off",
    "ember/require-tagless-components": "off",
    "no-prototype-builtins": "off",
  },
  overrides: [
    // node files
    {
      files: [
        "./.eslintrc.js",
        "./.prettierrc.js",
        "./.template-lintrc.js",
        "./ember-cli-build.js",
        "./testem.js",
        "./blueprints/*/index.js",
        "./config/**/*.js",
        "./lib/*/index.js",
        "./server/**/*.js",
      ],
      parserOptions: {
        sourceType: "script",
      },
      env: {
        browser: false,
        node: true,
      },
      plugins: ["node"],
      extends: ["plugin:node/recommended"],
      rules: {
        // this can be removed once the following is fixed
        // https://github.com/mysticatea/eslint-plugin-node/issues/77
        "node/no-unpublished-require": "off",
      },
    },
    {
      // Test files:
      files: ["tests/**/*-test.{js,ts}"],
      extends: ["plugin:qunit/recommended"],
      rules: {
        "qunit/require-expect": "off",
      },
    },
  ],
};

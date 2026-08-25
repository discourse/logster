module.exports = {
  plugins: ["ember-template-lint-plugin-discourse"],
  extends: "discourse:recommended",
  rules: {
    "no-invalid-interactive": "off",
    "require-input-label": "off",
    "require-valid-alt-text": "off",
  },
};

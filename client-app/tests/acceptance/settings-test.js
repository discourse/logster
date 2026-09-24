import { find, visit } from "@ember/test-helpers";
import { setupApplicationTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import SettingsRoute from "client-app/routes/settings";

module("Acceptance | settings", function (hooks) {
  setupApplicationTest(hooks);

  hooks.beforeEach(function () {
    this.modelStub = sinon.stub(SettingsRoute.prototype, "model").resolves({
      suppression: [
        { hard: true, value: "/coded-pattern/" },
        { hard: false, value: "/custom-pattern/" },
      ],
      grouping: [{ value: "/grouping-pattern/" }],
    });
  });

  hooks.afterEach(function () {
    this.modelStub.restore();
  });

  test("it renders settings returned as plain JSON arrays", async function (assert) {
    await visit("/settings");

    assert.dom(".settings-page").exists();
    assert.dom(".suppression-patterns .pattern-input").exists({ count: 2 });
    assert.dom(".grouping-patterns .pattern-input").exists({ count: 1 });

    const inputStyles = getComputedStyle(
      find(".suppression-patterns .pattern-input")
    );
    assert.strictEqual(inputStyles.paddingLeft, "8px");
    assert.strictEqual(inputStyles.paddingRight, "8px");
  });
});

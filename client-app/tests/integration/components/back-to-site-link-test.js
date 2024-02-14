import { module, test } from "qunit";
import { setupRenderingTest } from "ember-qunit";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";

module("Integration | Component | back-to-site-link", function (hooks) {
  setupRenderingTest(hooks);

  test("With path and text paremeter", async function (assert) {
    await render(hbs`<BackToSiteLink @path="/admin" @text="back to site"/>`);
    assert.dom("#back-to-site-panel a").exists("It shows back to site link");
  });

  test("Without required paremeters", async function (assert) {
    await render(hbs`<BackToSiteLink />`);
    assert
      .dom("#back-to-site-panel a")
      .doesNotExist("It does not show back link to site");
  });
});

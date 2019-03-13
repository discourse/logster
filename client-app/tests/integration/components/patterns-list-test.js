import { module, test } from "qunit";
import { setupRenderingTest } from "ember-qunit";
import hbs from "htmlbars-inline-precompile";
import { fillIn, render, find, findAll, click } from "@ember/test-helpers";

module("Integration | Component | patterns-list", function(hooks) {
  setupRenderingTest(hooks);

  test("it renders", async function(assert) {
    this.setProperties({
      mutable: true,
      patterns: []
    });
    await render(hbs`{{patterns-list patterns=patterns mutable=mutable}}`);
    assert
      .dom(".pattern-input")
      .exists("It shows an input when patterns are emtpy");
    assert
      .dom(".btn.new-pattern")
      .exists("It shows a create button when mutable");

    this.set("patterns", ["/somepattern/", "/anotherpattern/"]);
    assert.equal(
      findAll(".pattern-input").length,
      3,
      "It correctly displays patterns"
    );
    assert
      .dom(".btn.save")
      .doesNotExist("No save buttons are shown when there is 0 buffer");

    let inputs = findAll(".pattern-input");
    await fillIn(inputs[0], "/newpattern/");
    await fillIn(inputs[2], "/anothernewpattern/");

    assert
      .dom(".btn.save")
      .exists("Save buttons are shown when there is buffer");
    assert.dom(".btn.trash").exists("Trash buttons are shown");

    let disabled = inputs.every(inp => inp.disabled);
    assert.notOk(
      disabled,
      "All inputs are not disabled when the list is mutable"
    );

    this.set("mutable", false);

    inputs = findAll(".pattern-input");
    disabled = inputs.every(inp => inp.disabled);
    assert.ok(disabled, "All inputs are disabled when the list is immutable");
    assert
      .dom(".btn.trash")
      .doesNotExist("Trash buttons are not shown when the list is immutable");
  });
});

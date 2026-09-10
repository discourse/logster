import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import Message from "client-app/models/message";
import { mutatePreload } from "client-app/lib/preload";

module("Unit | Route | show", function (hooks) {
  setupTest(hooks);

  test("it exists", function (assert) {
    let route = this.owner.lookup("route:show");
    assert.ok(route);
  });

  test("the model is a Message, not the raw JSON", async function (assert) {
    mutatePreload("/show/abc", { key: "abc", message: "hello", count: 2 });

    const model = await this.owner.lookup("route:show").model({ id: "abc" });

    assert.true(model instanceof Message);
    assert.true(model.showCount);
    assert.strictEqual(typeof model.protect, "function");
  });
});

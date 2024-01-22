import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import MessageCollection from "client-app/models/message-collection";
import sinon from "sinon";
import * as utilities from "client-app/lib/utilities";

module("Unit | Controller | index", function (hooks) {
  setupTest(hooks);
  const ajaxStub = sinon.stub(utilities, "ajax");

  test("uses search param to filter results", function (assert) {
    const controller = this.owner.lookup("controller:index");
    const messages = MessageCollection.create();
    const row1 = { message: "error tomtom", severity: 2, key: "ce1f53b0cc" };
    const row2 = { message: "error steaky", severity: 3, key: "b083352825" };

    messages.rows.addObjects([row1, row2]);
    controller.set("model", messages);

    assert.strictEqual(controller.searchTerm, null, "initial value is null");
    assert.deepEqual(controller.model.rows, [row1, row2], "all rows");

    ajaxStub.callsFake(async () => ({
      search: "tomtom",
      filter: [5],
      messages: [],
    }));
    controller.set("search", "tomtom");

    assert.strictEqual(
      controller.searchTerm,
      "tomtom",
      "search sets search term"
    );
    assert.strictEqual(
      ajaxStub.firstCall.args[0],
      "/messages.json",
      "get messages"
    );
    assert.deepEqual(
      ajaxStub.firstCall.args[1],
      { data: { filter: "5", search: "tomtom" }, method: "POST" },
      "with correct terms"
    );
  });

  test("Creating inline grouping patterns finds the longest matching prefix between selected messages", function (assert) {
    const controller = this.owner.lookup("controller:index");
    const messages = ["error foo tomtom", "error foo steaky", "error foo bar"];

    assert.deepEqual(
      controller.findLongestMatchingPrefix(messages),
      "error foo "
    );
  });

  test("Creating inline grouping patterns can handle special characters", function (assert) {
    const controller = this.owner.lookup("controller:index");
    let messages = [
      "error foo!/@ tomtom",
      "error foo!/@ steaky",
      "error foo!/@ bar",
    ];

    assert.deepEqual(
      controller.findLongestMatchingPrefix(messages),
      "error foo!/@ "
    );

    messages = ["/$home/sam/.r\benv/", "/$home/sam/.r\benv/"];

    assert.deepEqual(
      controller.findLongestMatchingPrefix(messages),
      "/$home/sam/.r\benv/"
    );
  });
});

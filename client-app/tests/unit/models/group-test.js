import { module, test } from "qunit";
import Group from "client-app/models/group";

module("Unit | Model | group", function () {
  test("messages remain observable when a member is removed", function (assert) {
    const group = Group.create({
      group: true,
      regex: "/timeout/",
      messages: [
        { key: "one", message: "First timeout" },
        { key: "two", message: "Second timeout" },
      ],
    });
    const firstMessage = group.messages[0];

    group.messages.removeObject(firstMessage);

    assert.strictEqual(group.messages.length, 1);
    assert.strictEqual(group.displayMessage, "Second timeout");
  });
});

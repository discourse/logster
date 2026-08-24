import { module, test } from "qunit";
import sinon from "sinon";
import Group from "client-app/models/group";
import MessageCollection from "client-app/models/message-collection";

module("Unit | Model | message collection", function () {
  test("showMoreBefore sends known grouping patterns", async function (assert) {
    const collection = MessageCollection.create();
    collection.rows.addObjects([
      { key: "first" },
      { group: true, regex: "/timeout/", row_id: "group-1" },
      { group: true, regex: "/database/", row_id: "group-2" },
    ]);
    const load = sinon.stub(collection, "load").resolves({ messages: [] });

    await collection.showMoreBefore();

    assert.deepEqual(load.firstCall.args, [
      {
        before: "first",
        knownGroups: ["/timeout/", "/database/"],
      },
    ]);
  });

  test("finds the selected message in a replacement group", function (assert) {
    const currentGroup = Group.create({
      group: true,
      regex: "/timeout/",
      messages: [{ key: "one" }, { key: "two" }],
    });
    const replacementGroup = Group.create({
      group: true,
      regex: "/timeout/",
      messages: [{ key: "one" }, { key: "two" }],
    });
    const collection = MessageCollection.create({
      currentRow: currentGroup,
      currentGroupedMessagesPosition: 1,
    });

    assert.strictEqual(collection.findEquivalentMessageIndex(replacementGroup), 1);
  });
});

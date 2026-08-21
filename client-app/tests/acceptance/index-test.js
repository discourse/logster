import { visit } from "@ember/test-helpers";
import { setupApplicationTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import MessageCollection from "client-app/models/message-collection";

module("Acceptance | index", function (hooks) {
  setupApplicationTest(hooks);

  hooks.beforeEach(function () {
    this.reloadStub = sinon
      .stub(MessageCollection.prototype, "reload")
      .resolves();
    this.loadMoreStub = sinon
      .stub(MessageCollection.prototype, "loadMore")
      .resolves();
  });

  hooks.afterEach(function () {
    this.reloadStub.restore();
    this.loadMoreStub.restore();
  });

  test("it renders the index actions", async function (assert) {
    await visit("/");

    assert.dom("button.clear").exists("the clear-logs action is rendered");
  });
});

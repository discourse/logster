import { currentURL, fillIn, triggerEvent, visit } from "@ember/test-helpers";
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

  test("a search query reloads exactly once outside rendering", async function (assert) {
    await visit("/?search=tomtom");

    const controller = this.owner.lookup("controller:index");
    assert.strictEqual(controller.model.search, "tomtom");
    assert.strictEqual(this.reloadStub.callCount, 1);
  });

  test("changing only the search query reloads with the new value", async function (assert) {
    await visit("/?search=foo");
    await visit("/?search=bar");

    const controller = this.owner.lookup("controller:index");
    assert.strictEqual(controller.search, "bar", "the URL state is current");
    assert.strictEqual(controller.model.search, "bar", "the collection is current");
    assert.strictEqual(this.reloadStub.callCount, 2, "each search is loaded once");
  });

  test("typing a search updates the URL and reloads the collection", async function (assert) {
    await visit("/");
    await fillIn("input.search", "needle");
    await triggerEvent("input.search", "keyup");

    const controller = this.owner.lookup("controller:index");
    assert.strictEqual(currentURL(), "/?search=needle");
    assert.strictEqual(controller.model.search, "needle");
    assert.strictEqual(this.reloadStub.callCount, 2, "the initial and searched models load once");
  });
});

import { click, fillIn, findAll, visit } from "@ember/test-helpers";
import { setupApplicationTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { mutatePreload } from "client-app/lib/preload";
import IndexController from "client-app/controllers/index";
import MessageCollection from "client-app/models/message-collection";
import Message from "client-app/models/message";
import IndexRoute from "client-app/routes/index";

function buttonWithText(text) {
  return findAll("button").find(
    (button) => button.textContent.trim() === text
  );
}

async function selectRowsAndOpenDialog() {
  await click("button.settings");
  for (const checkbox of findAll(".grouping-checkbox")) {
    await click(checkbox);
  }
  await click(buttonWithText("Create Grouping Pattern"));
}

module("Acceptance | index grouping patterns", function (hooks) {
  setupApplicationTest(hooks);

  hooks.beforeEach(function () {
    mutatePreload("patterns_enabled", true);

    this.collection = MessageCollection.create();
    this.collection.rows.addObjects([
      Message.create({ key: "alpha", message: "Alpha checkout failure", severity: 3 }),
      Message.create({ key: "beta", message: "Beta timeout reached", severity: 3 }),
      Message.create({ key: "gamma", message: "Gamma payload rejected", severity: 2 }),
    ]);

    this.requestStub = sinon.stub(IndexController.prototype, "request");
    this.modelStub = sinon
      .stub(IndexRoute.prototype, "model")
      .returns(this.collection);
    this.reloadStub = sinon.stub(this.collection, "reload").resolves();
    this.loadMoreStub = sinon.stub(this.collection, "loadMore").resolves();
  });

  hooks.afterEach(function () {
    mutatePreload("patterns_enabled", false);
    this.requestStub.restore();
    this.modelStub.restore();
    this.reloadStub.restore();
    this.loadMoreStub.restore();
  });

  test("three unrelated rows produce an editable grouping pattern", async function (assert) {
    await visit("/");
    await click("button.settings");

    assert.dom(".grouping-checkbox").exists({ count: 3 });
    for (const checkbox of findAll(".grouping-checkbox")) {
      await click(checkbox);
    }

    const createButton = buttonWithText("Create Grouping Pattern");
    assert.ok(createButton, "the create action appears after selecting rows");
    await click(createButton);

    assert.dom(".grouping-pattern-dialog").exists();
    assert
      .dom(".grouping-pattern-input")
      .hasValue(
        "(?:Alpha checkout failure|Beta timeout reached|Gamma payload rejected)"
      );

    await click(buttonWithText("Cancel"));
    assert.dom(".grouping-pattern-dialog").doesNotExist();
    assert.dom(".grouping-checkbox").exists({ count: 3 });
  });

  test("the suggested pattern can be edited and created", async function (assert) {
    this.requestStub.resolves({ pattern: "/checkout|timeout/" });
    await visit("/");
    await selectRowsAndOpenDialog();
    await fillIn(".grouping-pattern-input", "checkout|timeout");
    await click(buttonWithText("Create"));

    assert.deepEqual(this.requestStub.firstCall.args, [
      "/patterns/grouping.json",
      { method: "POST", data: { pattern: "checkout|timeout" } },
    ]);
    assert.dom(".grouping-pattern-dialog").doesNotExist();
    assert.dom(".grouping-checkbox").doesNotExist();
    assert.strictEqual(this.reloadStub.callCount, 2, "the rows are reloaded");
  });

  test("creation failures are shown and can be retried", async function (assert) {
    this.requestStub.onFirstCall().rejects({ responseText: "Invalid regular expression" });
    this.requestStub.onSecondCall().resolves({ pattern: "/recovered/" });
    await visit("/");
    await selectRowsAndOpenDialog();
    await fillIn(".grouping-pattern-input", "[");
    await click(buttonWithText("Create"));

    assert.dom(".grouping-pattern-dialog .api-error").hasText("Invalid regular expression");
    assert.dom(".grouping-pattern-dialog").exists("the dialog stays open");
    assert.dom(".grouping-pattern-input").isNotDisabled();

    await fillIn(".grouping-pattern-input", "recovered");
    assert.dom(".grouping-pattern-dialog .api-error").doesNotExist();
    await click(buttonWithText("Create"));
    assert.dom(".grouping-pattern-dialog").doesNotExist();
    assert.strictEqual(this.requestStub.callCount, 2);
  });
});

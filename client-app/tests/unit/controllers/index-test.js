import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import MessageCollection from "client-app/models/message-collection";
import sinon from "sinon";
import * as utilities from "client-app/lib/utilities";

module("Unit | Controller | index", function (hooks) {
  setupTest(hooks);
  const ajaxStub = sinon.stub(utilities, "ajax");

  hooks.beforeEach(function () {
    ajaxStub.resetHistory();
  });

  test("exposes the search query without reloading during render", function (assert) {
    const controller = this.owner.lookup("controller:index");
    const messages = MessageCollection.create();
    const row1 = { message: "error tomtom", severity: 2, key: "ce1f53b0cc" };
    const row2 = { message: "error steaky", severity: 3, key: "b083352825" };

    messages.rows.addObjects([row1, row2]);
    controller.set("model", messages);

    assert.strictEqual(controller.searchTerm, null, "initial value is null");
    assert.deepEqual(controller.model.rows, [row1, row2], "all rows");

    controller.set("search", "tomtom");

    assert.strictEqual(controller.searchTerm, "tomtom", "search term is exposed");
    assert.true(ajaxStub.notCalled, "reading the getter does not issue a request");
  });

  test("Creating inline grouping patterns finds the longest matching prefix between selected messages", function (assert) {
    const controller = this.owner.lookup("controller:index");
    const messages = ["error foo tomtom", "error foo steaky", "error foo bar"];

    assert.deepEqual(
      controller.findLongestMatchingPrefix(messages),
      "error foo "
    );
  });

  test("Grouping pattern suggestions fall back to escaped alternatives", function (assert) {
    const controller = this.owner.lookup("controller:index");

    assert.deepEqual(
      controller.groupingMessagesForRow({
        group: true,
        messages: [{ message: "first [failure]" }, { message: "second (failure)" }],
      }),
      ["first [failure]", "second (failure)"]
    );
    assert.strictEqual(
      controller.buildGroupingPatternSuggestion([
        "Alpha [failure]",
        "Beta (timeout)",
      ]),
      "(?:Alpha \\[failure\\]|Beta \\(timeout\\))"
    );
  });

  test("Grouping pattern suggestions stay below the backend size limit", function (assert) {
    const controller = this.owner.lookup("controller:index");
    const suggestion = controller.buildGroupingPatternSuggestion([
      `Alpha ${"a".repeat(200)}`,
      `Beta ${"b".repeat(200)}`,
      `Gamma ${"c".repeat(200)}`,
    ]);
    const heavilyEscapedSuggestion = controller.buildGroupingPatternSuggestion([
      `Alpha ${"/".repeat(200)}`,
      `Beta ${"\\".repeat(200)}`,
    ]);

    assert.true(suggestion.length <= 480, "the generated pattern is bounded");
    assert.true(
      controller.estimatedRubyRegexpInspectSize(suggestion) <= 490,
      "the client leaves room for Ruby's Regexp inspection"
    );
    assert.true(
      controller.estimatedRubyRegexpInspectSize(heavilyEscapedSuggestion) <= 490,
      "escaped characters also stay within the server limit"
    );
    assert.true(
      suggestion.startsWith("(?:Alpha "),
      "the suggestion retains the first selected message"
    );
    assert.true(suggestion.endsWith(")"), "the suggestion remains a complete regexp group");
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

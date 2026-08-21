import { click, fillIn, findAll, render } from "@ember/test-helpers";
import { setupRenderingTest } from "ember-qunit";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import sinon from "sinon";
import PatternsList from "client-app/components/patterns-list";
import Pattern from "client-app/models/pattern-item";

module("Integration | Component | patterns-list", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.requestStub = sinon.stub(PatternsList.prototype, "request");
  });

  hooks.afterEach(function () {
    this.requestStub.restore();
  });

  test("it renders mutable and immutable lists", async function (assert) {
    this.setProperties({ mutable: true, patterns: [] });
    await render(
      hbs`<PatternsList @patterns={{this.patterns}} @mutable={{this.mutable}} @key="suppression" />`
    );

    assert.dom(".pattern-input").exists("an empty mutable list starts with a draft");
    assert.dom(".btn.new-pattern").exists();

    const pattern1 = Pattern.create({ value: "/somepattern/", count: 6 });
    const pattern2 = Pattern.create({ value: "/anotherpattern/" });
    this.set("patterns", [pattern1, pattern2]);

    assert.dom(".pattern-input").exists({ count: 3 });
    assert.dom(".btn.save").doesNotExist("unchanged patterns have no save button");
    assert.dom("input.count").exists({ count: 3 });
    assert.ok(findAll("input.count").every((counter) => counter.disabled));
    assert.ok(findAll("input.count").some((counter) => counter.value === "6"));

    await fillIn(findAll(".pattern-input")[0], "/newpattern/");
    await fillIn(findAll(".pattern-input")[2], "/anothernewpattern/");
    assert.dom(".btn.save").exists();
    assert.dom(".btn.trash").exists();

    this.set("mutable", false);
    assert.ok(findAll(".pattern-input").every((input) => input.disabled));
    assert.dom(".btn.trash").doesNotExist();
    assert.dom(".btn.new-pattern").doesNotExist();
  });

  test("draft patterns can be added and discarded locally", async function (assert) {
    this.set("patterns", []);
    await render(
      hbs`<PatternsList @patterns={{this.patterns}} @mutable={{true}} @key="grouping" />`
    );

    assert.dom(".pattern-input").exists({ count: 1 });
    await click(".btn.new-pattern");
    assert.dom(".pattern-input").exists({ count: 2 });

    await click(findAll(".btn.trash")[0]);
    assert.dom(".pattern-input").exists({ count: 1 });
    assert.notOk(this.requestStub.called, "discarding a draft does not call the API");
  });

  test("a newly saved pattern can be deleted without leaving a stale row", async function (assert) {
    this.requestStub.onFirstCall().resolves({ pattern: "/aaa/" });
    this.requestStub.onSecondCall().resolves("OK");

    this.set("patterns", []);
    await render(
      hbs`<PatternsList
        @patterns={{this.patterns}}
        @mutable={{true}}
        @key="suppression"
        @applyRetroactivelyCheckbox={{true}}
      />`
    );

    await fillIn(".pattern-input", "aaa");
    await click(".retro-checkbox input");
    await click(".btn.save");

    assert.deepEqual(this.requestStub.firstCall.args, [
      "/patterns/suppression.json",
      { method: "POST", data: { pattern: "aaa", retroactive: true } },
    ]);
    assert.dom(".pattern-input").hasValue("/aaa/");
    assert.dom(".retro-checkbox").doesNotExist("the saved pattern is no longer a draft");

    await click(".btn.trash");

    assert.deepEqual(this.requestStub.secondCall.args, [
      "/patterns/suppression.json",
      { method: "DELETE", data: { pattern: "/aaa/" } },
    ]);
    assert.dom(".pattern-input").doesNotExist("the deleted row is removed immediately");
    assert.dom(".api-error").doesNotExist();
  });

  test("an existing pattern can be edited and its count is reset", async function (assert) {
    this.requestStub.resolves({ pattern: "/new-pattern/" });
    this.set("patterns", [Pattern.create({ value: "/old-pattern/", count: 9 })]);

    await render(
      hbs`<PatternsList @patterns={{this.patterns}} @mutable={{true}} @key="suppression" />`
    );
    await fillIn(".pattern-input", "new-pattern");
    await click(".btn.save");

    assert.deepEqual(this.requestStub.firstCall.args, [
      "/patterns/suppression.json",
      {
        method: "PUT",
        data: { pattern: "/old-pattern/", new_pattern: "new-pattern" },
      },
    ]);
    assert.dom(".pattern-input").hasValue("/new-pattern/");
    assert.dom("input.count").hasValue("0");
    assert.dom(".btn.save").doesNotExist();
  });

  test("API errors remain actionable and clear on retry", async function (assert) {
    this.requestStub.onFirstCall().rejects({ responseText: "Not found" });
    this.requestStub.onSecondCall().resolves({ pattern: "/recovered/" });
    this.set("patterns", [Pattern.create({ value: "/old/" })]);

    await render(
      hbs`<PatternsList @patterns={{this.patterns}} @mutable={{true}} @key="grouping" />`
    );
    await fillIn(".pattern-input", "recovered");
    await click(".btn.save");

    assert.dom(".api-error").hasText("Not found");
    assert.dom(".pattern-input").isNotDisabled();
    assert.dom(".btn.save").exists("the failed change can be retried");

    await click(".btn.save");
    assert.dom(".api-error").doesNotExist();
    assert.dom(".pattern-input").hasValue("/recovered/");
  });

  test("suppression counts can be reset", async function (assert) {
    this.requestStub.resolves("OK");
    this.set("patterns", [Pattern.create({ value: "/noisy/", count: 12, hard: false })]);

    await render(
      hbs`<PatternsList @patterns={{this.patterns}} @mutable={{true}} @key="suppression" />`
    );
    await click(".btn.reset");

    assert.deepEqual(this.requestStub.firstCall.args, [
      "/reset-count.json",
      { method: "PUT", data: { pattern: "/noisy/", hard: false } },
    ]);
    assert.dom("input.count").hasValue("0");
    assert.dom(".btn.reset").isDisabled();
  });
});

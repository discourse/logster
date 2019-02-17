import { module, test } from "qunit";
import { setupRenderingTest } from "ember-qunit";
import { render, find, findAll, click } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import Message from "client-app/models/message";
import { init } from "client-app/lib/preload";

const message = Message.create({
  env: [{ a: "aa", b: "bb" }, { c: "cc", d: "dd" }]
});

const message2 = Message.create({
  env: { e: "ee", f: "ff" }
});

const message3 = Message.create({
  env: [
    { env_key_2: "an_env_value", notExpanded: "dsdcz" },
    { env_key_2: "anotherthing", notExpanded: "cxc" }
  ]
});

function reduceToContent(node) {
  return Array.from(node.childNodes).reduce(
    (ac, cr) => `${ac.textContent}: ${cr.textContent}`
  );
}

module("Integration | Component | env-tab", function(hooks) {
  setupRenderingTest(hooks);

  test("it renders", async function(assert) {
    this.set("message", message);
    await render(hbs`{{env-tab message=message}}`);

    assert.equal(
      find(".env-number").textContent,
      "1/2",
      "shows the current over the total number of env objects"
    );
    let trs = findAll("tr");
    assert.equal(trs.length, 2);
    assert.equal(reduceToContent(trs[0]), "a: aa", "has the right content");
    assert.equal(reduceToContent(trs[1]), "b: bb", "has the right content");

    const buttons = findAll("button.nav-btn");
    // at first page, you can't go back
    assert.ok(buttons[0].disabled, "back buttons are disabled");
    assert.ok(buttons[1].disabled, "back buttons are disabled");

    assert.notOk(buttons[2].disabled, "forward buttons are not disabled");
    assert.notOk(buttons[3].disabled, "forward buttons are not disabled");

    this.set("message", message2);
    assert.dom("button").doesNotExist("doesn't show buttons for non-array env");

    trs = findAll("tr");
    assert.equal(trs.length, 2);
    assert.equal(reduceToContent(trs[0]), "e: ee", "has the right content");
    assert.equal(reduceToContent(trs[1]), "f: ff", "has the right content");
  });

  test("it works correctly", async function(assert) {
    this.set("message", message);
    await render(hbs`{{env-tab message=message}}`);

    const buttons = findAll("button.nav-btn");
    await click(buttons[2]);

    assert.equal(
      find(".env-number").textContent,
      "2/2",
      "shows the current over the total number of env objects"
    );

    const trs = findAll("tr");
    assert.equal(trs.length, 2);
    assert.equal(reduceToContent(trs[0]), "c: cc", "has the right content");
    assert.equal(reduceToContent(trs[1]), "d: dd", "has the right content");

    // at last page, you can't go forward but you can go back
    assert.notOk(buttons[0].disabled, "back buttons are not disabled");
    assert.notOk(buttons[1].disabled, "back buttons are not disabled");

    assert.ok(buttons[2].disabled, "forward buttons are disabled");
    assert.ok(buttons[3].disabled, "forward buttons are disabled");
  });

  test("expandable env keys", async function(assert) {
    document.getElementById(
      "preloaded-data"
    ).dataset.preloaded = JSON.stringify({
      env_expandable_keys: ["env_key_2"]
    });
    init();
    this.set("message", message3);
    await render(hbs`{{env-tab message=message}}`);

    const expandable = find(".env-table tr");
    assert.equal(
      expandable.children[1].textContent.trim(),
      "an_env_value, 1 more",
      "expandable env keys shown correctly"
    );

    assert.equal(
      findAll("a.expand-list").length,
      1,
      "only whitelisted env keys are expandable"
    );

    const expandBtn = find("a.expand-list");
    assert.equal(expandBtn.textContent.trim(), "1 more");
    await click(expandBtn);

    const expanded = find(".env-table tr");
    assert.equal(
      expanded.children[1].textContent.trim(),
      "[an_env_value, anotherthing]",
      "expanded env keys shown correctly"
    );
  });
});

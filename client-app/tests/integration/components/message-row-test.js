import { render } from "@ember/test-helpers";
import { setupRenderingTest } from "ember-qunit";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import Group from "client-app/models/group";

module("Integration | Component | message-row", function (hooks) {
  setupRenderingTest(hooks);

  test("a grouped row uses its first message as the title", async function (assert) {
    this.set(
      "group",
      Group.create({
        group: true,
        regex: "/Unicode payload/",
        count: 3,
        messages: [
          { message: "Unicode payload failed: café ☕", severity: 2 },
          { message: "Unicode payload failed: façade", severity: 2 },
        ],
      })
    );

    this.set("selectRow", () => {});
    await render(
      hbs`<MessageRow @model={{this.group}} @selectRow={{this.selectRow}} />`
    );

    assert
      .dom(".message-body")
      .hasText("Unicode payload failed: café ☕");
  });
});

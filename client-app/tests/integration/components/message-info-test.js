import { module, test } from "qunit";
import { setupRenderingTest } from "ember-qunit";
import { render, find, findAll, click } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import Message from "client-app/models/message";

const backtrace = "test backtrace:26";
const messageTitle = "This Is Title";

const message = Message.create({
  backtrace,
  message: messageTitle,
  env: { c: "cc", d: "dd" }
});

module("Integration | Component | message-info", function(hooks) {
  setupRenderingTest(hooks);

  test("it renders", async function(assert) {
    const callback = newPosition => this.set("currentEnvPosition", newPosition);
    this.setProperties({
      actionsInMenu: true,
      showTitle: false,
      envPosition: 0,
      message,
      callback
    });

    await render(
      hbs`{{message-info
            currentMessage=message
            showTitle=showTitle
            currentEnvPosition=envPosition
            envChangedAction=callback
            showShare=true
            actionsInMenu=actionsInMenu}}`
    );
    let activeTab = find(".message-info .content.active pre");
    assert.equal(
      activeTab.textContent.trim(),
      backtrace,
      "default active tab is backtrace"
    );
    assert.dom(".message-info .content h3").doesNotExist("no titles are shown");
    assert.equal(findAll(".tabs a").length, 3, "3 tabs shown");
    assert.equal(
      find(".tabs a.active").textContent.trim(),
      "backtrace",
      "default active tab is backtrace"
    );
    assert.equal(
      findAll(".message-actions button").length,
      2,
      "2 buttons shown when `actionsInMenu` is true"
    );
    assert
      .dom(".message-actions button.expand.no-text")
      .exists("menu expand button is shown");
    assert.dom(".message-actions button.share").exists("share button is shown");

    await click(find(".message-actions button.expand.no-text"));
    assert.equal(
      findAll(".actions-menu button").length,
      3,
      "extra buttons shown inside a menu"
    );
    assert
      .dom(".actions-menu button.remove")
      .exists("remove button inside the menu");
    assert
      .dom(".actions-menu button.protect")
      .exists("protect button inside the menu");

    this.setProperties({
      showTitle: true,
      actionsInMenu: false
    });

    assert.equal(
      findAll(".message-info .content h3").length,
      3,
      "titles are shown"
    );
    assert
      .dom(".message-actions button.expand.no-text")
      .doesNotExist("menu expand button is not shown");
    assert.equal(
      findAll(".message-actions button").length,
      4,
      "all actions buttons are shown inline when `actionsInMenu` is false"
    );

    await click(findAll(".tabs a")[0]);
    activeTab = find(".message-info .content.active pre");
    assert.equal(activeTab.textContent, messageTitle, "can switch tabs");

    assert
      .dom(".message-actions button.solve")
      .doesNotExist(
        "no solve button when there is no application_version in env"
      );

    message.set("env.application_version", "fddfsdfdsf");
    this.set("message", message);
    assert
      .dom(".message-actions button.solve")
      .exists("solve button is shown when there is application_version in env");

    message.set("env", [
      { sd: "dx", application_version: "fsfdsf" },
      { vcv: "dxc" }
    ]);
    this.set("message", message);
    assert
      .dom(".message-actions button.solve")
      .exists(
        "solve button is shown when there is application_version in env (array)"
      );
  });
});

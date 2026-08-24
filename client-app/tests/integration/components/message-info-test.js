import { module, test } from "qunit";
import { setupRenderingTest } from "ember-qunit";
import { click, find, findAll, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import Message from "client-app/models/message";
import MessageInfoComponent from "client-app/components/message-info";
import sinon from "sinon";

const backtrace = "test backtrace:26";
const messageTitle = "This Is Title";

const message = Message.create({
  backtrace,
  message: messageTitle,
  env: { c: "cc", d: "dd" },
});

module("Integration | Component | message-info", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders", async function (assert) {
    const callback = (newPosition) =>
      this.set("currentEnvPosition", newPosition);
    this.setProperties({
      actionsInMenu: true,
      showTitle: false,
      envPosition: 0,
      message,
      callback,
    });

    await render(
      hbs`<MessageInfo
        @currentMessage={{this.message}}
        @showTitle={{this.showTitle}}
        @currentEnvPosition={{this.envPosition}}
        @envChangedAction={{this.callback}}
        @showShare={{true}}
        @actionsInMenu={{this.actionsInMenu}}
      />`
    );
    let activeTab = find(".message-info .content.active pre");
    assert.strictEqual(
      activeTab.textContent.trim(),
      backtrace,
      "default active tab is backtrace"
    );
    assert.dom(".message-info .content h3").doesNotExist("no titles are shown");
    assert.strictEqual(findAll(".tabs a").length, 3, "3 tabs shown");
    assert.strictEqual(
      find(".tabs a.active").textContent.trim(),
      "backtrace",
      "default active tab is backtrace"
    );
    assert.strictEqual(
      findAll(".message-actions button").length,
      2,
      "2 buttons shown when `actionsInMenu` is true"
    );
    assert
      .dom(".message-actions button.expand.no-text")
      .exists("menu expand button is shown");
    assert.dom(".message-actions button.share").exists("share button is shown");

    await click(find(".message-actions button.expand.no-text"));
    assert.strictEqual(
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
      actionsInMenu: false,
    });

    assert.strictEqual(
      findAll(".message-info .content h3").length,
      3,
      "titles are shown"
    );
    assert
      .dom(".message-actions button.expand.no-text")
      .doesNotExist("menu expand button is not shown");
    assert.strictEqual(
      findAll(".message-actions button").length,
      4,
      "all actions buttons are shown inline when `actionsInMenu` is false"
    );

    await click(findAll(".tabs a")[0]);
    activeTab = find(".message-info .content.active pre");
    assert.strictEqual(activeTab.textContent, messageTitle, "can switch tabs");

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
      { vcv: "dxc" },
    ]);
    this.set("message", message);
    assert
      .dom(".message-actions button.solve")
      .exists(
        "solve button is shown when there is application_version in env (array)"
      );
  });

  test("protect and unprotect update the available action immediately", async function (assert) {
    const currentMessage = Message.create({
      backtrace,
      message: messageTitle,
      env: {},
      protected: false,
    });
    const protect = sinon
      .stub(currentMessage, "protect")
      .callsFake(() => currentMessage.set("protected", true));
    const unprotect = sinon
      .stub(currentMessage, "unprotect")
      .callsFake(() => currentMessage.set("protected", false));
    this.setProperties({ currentMessage, noop: () => {} });

    await render(
      hbs`<MessageInfo
        @currentMessage={{this.currentMessage}}
        @removeMessage={{this.noop}}
        @solveMessage={{this.noop}}
        @actionsInMenu={{false}}
      />`
    );

    assert.dom("button.protect").exists();
    await click("button.protect");
    assert.true(protect.calledOnce);
    assert.dom("button.protect").doesNotExist();
    assert.dom("button.unprotect").exists("the action changes without selecting another row");

    await click("button.unprotect");
    assert.true(unprotect.calledOnce);
    assert.dom("button.unprotect").doesNotExist();
    assert.dom("button.protect").exists("the action changes back immediately");
  });

  test("failed protection requests restore the model and row", async function (assert) {
    const currentMessage = Message.create({
      backtrace,
      message: messageTitle,
      env: {},
      protected: false,
    });
    sinon.stub(currentMessage, "protect").callsFake(async () => {
      currentMessage.set("protected", true);
      throw new Error("request failed");
    });
    this.setProperties({ currentMessage, noop: () => {} });

    await render(
      hbs`<MessageInfo
        @currentMessage={{this.currentMessage}}
        @removeMessage={{this.noop}}
        @solveMessage={{this.noop}}
        @actionsInMenu={{false}}
      />
      <MessageRow @model={{this.currentMessage}} @selectRow={{this.noop}} />`
    );

    await click("button.protect");

    assert.false(currentMessage.protected, "the model returns to its previous state");
    assert.dom("button.protect").exists("the action returns to its previous state");
    assert.dom(".message-row .protected svg").doesNotExist("the row does not show a lock");
  });

  test("protection overrides release completed message references", async function (assert) {
    const currentMessage = Message.create({ protected: false });
    sinon.stub(currentMessage, "protect").callsFake(async () => {
      currentMessage.set("protected", true);
    });
    const component = new MessageInfoComponent(this.owner, { currentMessage });

    await component.protect();

    assert.strictEqual(component.protectionOverrides.size, 0);
    assert.true(currentMessage.protected);
  });

  test("copy reports success to the user", async function (assert) {
    const originalClipboard = Object.getOwnPropertyDescriptor(
      navigator,
      "clipboard"
    );
    const writeText = sinon.stub();
    writeText.onFirstCall().resolves();
    writeText.onSecondCall().rejects(new Error("permission denied"));
    Object.defineProperty(navigator, "clipboard", {
      configurable: true,
      value: { writeText },
    });

    const currentMessage = Message.create({
      backtrace,
      message: messageTitle,
      env: { HTTP_HOST: "forum.example.com" },
    });
    this.setProperties({ currentMessage, noop: () => {} });

    try {
      await render(
        hbs`<MessageInfo
          @currentMessage={{this.currentMessage}}
          @removeMessage={{this.noop}}
          @solveMessage={{this.noop}}
          @actionsInMenu={{false}}
        />`
      );
      await click("button.copy");

      assert.true(writeText.calledOnce);
      assert.dom("button.copy").hasText("Copied!");
      assert.dom("button.copy").hasClass("copied");

      await click("button.copy");
      assert.true(writeText.calledTwice);
      assert.dom("button.copy").hasText("Copy failed");
      assert.dom("button.copy").hasClass("copy-failed");
    } finally {
      if (originalClipboard) {
        Object.defineProperty(navigator, "clipboard", originalClipboard);
      } else {
        delete navigator.clipboard;
      }
    }
  });
});

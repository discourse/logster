import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import { eq, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import FaIcon from "@fortawesome/ember-fontawesome/components/fa-icon";
import ActionsMenu from "client-app/components/actions-menu";
import BackTrace from "client-app/components/back-trace";
import EnvTab from "client-app/components/env-tab";
import Preload from "client-app/lib/preload";

const TABS = [
  { name: "info", hint: "show info" },
  { name: "backtrace", hint: "show backtrace" },
  { name: "env", hint: "show environment" },
];

export default class MessageInfo extends Component {
  @tracked copyState = "idle";
  @tracked protectionOverrides = new Map();
  @tracked selectedTab = "backtrace";
  copyResetTimer = null;
  tabs = TABS;

  constructor() {
    super(...arguments);
    registerDestructor(this, () => clearTimeout(this.copyResetTimer));
  }

  get isProtected() {
    const message = this.args.currentMessage;
    return this.protectionOverrides.has(message)
      ? this.protectionOverrides.get(message)
      : Boolean(message.protected);
  }

  get showSolveAllButton() {
    return Boolean(this.args.currentRow?.group);
  }

  get showSolveButton() {
    if (this.showSolveAllButton) {
      return false;
    }
    return this.args.currentMessage.env
      ? this.args.currentMessage.canSolve
      : Boolean(Preload.get("application_version"));
  }

  get buttons() {
    const buttons = [];
    const isProtected = this.isProtected;

    if (!isProtected && this.showSolveButton) {
      buttons.push({
        klass: "solve",
        action: this.solve,
        icon: "check-square",
        label: "Solve",
        prefix: "far",
        danger: true,
      });
    }

    if (this.showSolveAllButton) {
      buttons.push({
        klass: "solve-all",
        action: this.solveAll,
        icon: "check-square",
        label: "Solve All",
        prefix: "far",
        danger: true,
      });
    }

    if (isProtected) {
      buttons.push({
        klass: "unprotect",
        action: this.unprotect,
        icon: "unlock",
        prefix: "fas",
        label: "Unprotect",
      });
    } else {
      buttons.push(
        {
          klass: "remove",
          action: this.remove,
          icon: "trash-alt",
          label: "Remove",
          prefix: "far",
          danger: true,
        },
        {
          klass: "protect",
          action: this.protect,
          icon: "lock",
          prefix: "fas",
          label: "Protect",
        }
      );
    }

    const copySucceeded = this.copyState === "copied";
    const copyFailed = this.copyState === "failed";
    buttons.push({
      klass: `copy${copySucceeded ? " copied" : ""}${copyFailed ? " copy-failed" : ""}`,
      action: this.copy,
      icon: copySucceeded ? "check" : copyFailed ? "exclamation-circle" : "copy",
      prefix: copySucceeded || copyFailed ? "fas" : "far",
      label: copySucceeded ? "Copied!" : copyFailed ? "Copy failed" : "Copy",
      live: true,
    });

    return buttons;
  }

  @action
  selectTab(tabName, event) {
    event?.preventDefault();
    this.selectedTab = tabName;
    this.args.onTabChange?.(tabName);
  }

  @action
  async copy() {
    const currentMessage = this.args.currentMessage;
    const header = currentMessage.showCount
      ? `Message (${currentMessage.count} copies reported)`
      : "Message";
    const message = `${header}\n\n${currentMessage.message}`;
    const backtrace = `Backtrace\n\n${currentMessage.backtrace}`;
    const env = currentMessage.env;
    const httpHosts = Array.isArray(env)
      ? [...new Set(env.map((item) => item.HTTP_HOST).filter(Boolean))].join(
          ", "
        )
      : env?.HTTP_HOST;
    const envText = httpHosts ? `Env\n\nHTTP HOSTS: ${httpHosts}` : "";
    const text = [message, backtrace, envText].filter(Boolean).join("\n\n");

    try {
      await this.writeToClipboard(text);
      this.showCopyStatus("copied");
    } catch {
      this.showCopyStatus("failed");
    }
  }

  async writeToClipboard(text) {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
      return;
    }

    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    textarea.value = text;
    textarea.select();
    const copied = document.execCommand("copy");
    textarea.remove();

    if (!copied) {
      throw new Error("Clipboard copy failed");
    }
  }

  showCopyStatus(state) {
    clearTimeout(this.copyResetTimer);
    this.copyState = state;
    this.copyResetTimer = setTimeout(() => {
      this.copyState = "idle";
      this.copyResetTimer = null;
    }, 2_000);
  }

  setProtectionState(message, isProtected) {
    const overrides = new Map(this.protectionOverrides);
    overrides.set(message, isProtected);
    this.protectionOverrides = overrides;
  }

  clearProtectionState(message) {
    const overrides = new Map(this.protectionOverrides);
    overrides.delete(message);
    this.protectionOverrides = overrides;
  }

  @action
  async protect() {
    const message = this.args.currentMessage;
    const previousState = this.isProtected;
    this.setProtectionState(message, true);

    try {
      await message.protect();
    } catch {
      message.set("protected", previousState);
    } finally {
      this.clearProtectionState(message);
    }
  }

  @action
  async unprotect() {
    const message = this.args.currentMessage;
    const previousState = this.isProtected;
    this.setProtectionState(message, false);

    try {
      await message.unprotect();
    } catch {
      message.set("protected", previousState);
    } finally {
      this.clearProtectionState(message);
    }
  }

  @action
  remove() {
    this.args.removeMessage(this.args.currentMessage);
  }

  @action
  solve() {
    this.args.solveMessage(this.args.currentMessage);
  }

  @action
  solveAll() {
    this.args.currentRow.solveAll();
  }

  @action
  share() {
    window.location.pathname = this.args.currentMessage.shareUrl;
  }

  <template>
    <div class="message-info" ...attributes>
      <div class="tabbed-section">
        <ul class="tabs">
          {{#each this.tabs as |tab|}}
            <li>
              <a
                title={{tab.hint}}
                href="#"
                class={{if (eq this.selectedTab tab.name) "active"}}
                {{on "click" (fn this.selectTab tab.name)}}
              >
                {{tab.name}}
              </a>
            </li>
          {{/each}}
        </ul>

        <div class="content info {{if (eq this.selectedTab 'info') 'active'}}">
          {{#if @showTitle}}
            <h3>
              Message
              {{#if @currentMessage.showCount}}
                ({{@currentMessage.count}} copies reported)
              {{/if}}
            </h3>
          {{/if}}
          <pre>{{@currentMessage.message}}</pre>
        </div>

        <div
          class="content backtrace {{if (eq this.selectedTab 'backtrace') 'active'}}"
        >
          {{#if @showTitle}}<h3>Backtrace</h3>{{/if}}
          <pre><BackTrace
              class="backtrace"
              @backtrace={{@currentMessage.backtrace}}
              @env={{@currentMessage.env}}
            /></pre>
        </div>

        <div class="content env {{if (eq this.selectedTab 'env') 'active'}}">
          {{#if @currentMessage.env}}
            {{#if @showTitle}}<h3>Env</h3>{{/if}}
            <EnvTab
              @message={{@currentMessage}}
              @currentEnvPosition={{@currentEnvPosition}}
              @envChangedAction={{@envChangedAction}}
            />
          {{else if @loadingEnv}}
            Loading env...
          {{else}}
            No env for this message.
          {{/if}}
        </div>
      </div>

      {{#if @currentMessage}}
        <div class="message-actions">
          <ActionsMenu
            @actionsInMenu={{@actionsInMenu}}
            @showShare={{@showShare}}
            @share={{this.share}}
          >
            {{#each this.buttons as |actionButton|}}
              <button
                class="{{actionButton.klass}} btn {{if actionButton.danger 'danger'}}"
                type="button"
                {{on "click" actionButton.action}}
              >
                <FaIcon
                  @icon={{actionButton.icon}}
                  @prefix={{actionButton.prefix}}
                />
                <span aria-live={{if actionButton.live "polite"}}>
                  {{actionButton.label}}
                </span>
              </button>
            {{/each}}
          </ActionsMenu>
        </div>
      {{/if}}
    </div>
  </template>
}

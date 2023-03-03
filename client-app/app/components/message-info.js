import classic from "ember-classic-decorator";
import { bool } from "@ember/object/computed";
import Component from "@ember/component";
import { action, computed } from "@ember/object";
import Preload from "client-app/lib/preload";

@classic
export default class MessageInfo extends Component {
  @bool("currentRow.group") showSolveAllButton;

  @computed("currentMessage.protected", "showSolveAllButton", "showSolveButton")
  get buttons() {
    const protect = this.currentMessage.protected;
    const buttons = [];

    if (!protect && this.showSolveButton) {
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

    if (!protect) {
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
    } else {
      buttons.push({
        klass: "unprotect",
        action: this.unprotect,
        icon: "unlock",
        prefix: "fas",
        label: "Unprotect",
      });
    }

    buttons.push({
      klass: "copy",
      action: this.copy,
      icon: "copy",
      prefix: "far",
      label: "Copy",
    });

    return buttons;
  }

  @computed("showSolveAllButton", "currentMessage.{canSolve,env}")
  get showSolveButton() {
    if (this.showSolveAllButton) {
      return false;
    }
    // env isn't loaded until you switch to the env tab
    // so if we don't have env we show the button if
    // application_version is provided in the config
    return this.currentMessage.env
      ? this.currentMessage.canSolve
      : !!Preload.get("application_version");
  }

  @action
  copy() {
    const temp = document.createElement("TEXTAREA");
    document.body.appendChild(temp);
    const header = this.currentMessage.showCount
      ? `Message (${this.currentMessage.count} copies reported)`
      : "Message";
    const message = `${header}\n\n${this.currentMessage.message}`;

    const backtrace = `Backtrace\n\n${this.currentMessage.backtrace
      .split("\n")
      .slice(0, 10)
      .join("\n")}`;

    const httpHosts = Array.isArray(this.currentMessage.env)
      ? this.currentMessage.env
          .map((e) => e["HTTP_HOST"])
          .filter((e, i, a) => e && a.indexOf(e) === i)
          .join(", ")
      : this.currentMessage.env["HTTP_HOST"];

    const env = httpHosts ? `Env\n\nHTTP HOSTS: ${httpHosts}` : "";
    const lines = [message, backtrace, env].filter((l) => l).join("\n\n");
    temp.value = lines;
    temp.select();
    document.execCommand("copy");
    document.body.removeChild(temp);
  }

  @action
  tabChanged(newTab) {
    this.onTabChange?.(newTab);
  }

  @action
  protect() {
    this.currentMessage.protect();
  }

  @action
  unprotect() {
    this.currentMessage.unprotect();
  }

  @action
  remove() {
    this.removeMessage(this.currentMessage);
  }

  @action
  solve() {
    this.solveMessage(this.currentMessage);
  }

  @action
  solveAll() {
    this.currentRow.solveAll();
  }

  @action
  share() {
    window.location.pathname = this.currentMessage.shareUrl;
  }
}

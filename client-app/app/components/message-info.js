import Component from "@ember/component";
import { computed } from "@ember/object";
import Preload from "client-app/lib/preload";
import { bool } from "@ember/object/computed";

export default Component.extend({
  showSolveAllButton: bool("currentRow.group"),

  buttons: computed("currentMessage.protected", "showSolveButton", function() {
    const protect = this.get("currentMessage.protected");
    const buttons = [];
    const prefix = "fas";

    if (!protect && this.showSolveButton) {
      buttons.push({
        klass: "solve",
        action: "solve",
        icon: "check-square",
        label: "Solve",
        prefix: "far",
        danger: true
      });
    }

    if (this.showSolveAllButton) {
      buttons.push({
        klass: "solve-all",
        action: "solveAll",
        icon: "check-square",
        label: "Solve All",
        prefix: "far",
        danger: true
      });
    }

    if (!protect) {
      buttons.push(
        {
          klass: "remove",
          action: "remove",
          icon: "trash-alt",
          label: "Remove",
          prefix: "far",
          danger: true
        },
        {
          klass: "protect",
          action: "protect",
          icon: "lock",
          prefix,
          label: "Protect"
        }
      );
    } else {
      buttons.push({
        klass: "unprotect",
        action: "unprotect",
        icon: "unlock",
        prefix,
        label: "Unprotect"
      });
    }

    buttons.push({
      klass: "copy",
      action: "copyAction",
      icon: "copy",
      prefix: "far",
      label: "Copy"
    });
    return buttons;
  }),

  showSolveButton: computed(
    "showSolveAllButton",
    "currentMessage.{canSolve,env}",
    function() {
      if (this.showSolveAllButton) return false;
      // env isn't loaded until you switch to the env tab
      // so if we don't have env we show the button if
      // application_version is provided in the config
      return this.currentMessage.env
        ? this.currentMessage.canSolve
        : !!Preload.get("application_version");
    }
  ),

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
          .map(e => e["HTTP_HOST"])
          .filter((e, i, a) => e && a.indexOf(e) === i)
          .join(", ")
      : this.currentMessage.env["HTTP_HOST"];

    const env = httpHosts ? `Env\n\nHTTP HOSTS: ${httpHosts}` : "";
    const lines = [message, backtrace, env].filter(l => l).join("\n\n");
    temp.value = lines;
    temp.select();
    document.execCommand("copy");
    document.body.removeChild(temp);
  },

  actions: {
    tabChanged(newTab) {
      if (this.onTabChange) {
        this.onTabChange(newTab);
      }
    },

    protect() {
      this.currentMessage.protect();
    },

    unprotect() {
      this.currentMessage.unprotect();
    },

    remove() {
      this.removeMessage(this.currentMessage);
    },

    solve() {
      this.solveMessage(this.currentMessage);
    },

    solveAll() {
      this.currentRow.solveAll();
    },

    share() {
      window.location.pathname = this.get("currentMessage.shareUrl");
    },

    copyAction() {
      this.copy();
    }
  }
});

import Component from "@ember/component";
import { computed } from "@ember/object";
import Preload from "client-app/lib/preload";
import { bool } from "@ember/object/computed";

export default Component.extend({
  showSolveAllButton: bool("currentRow.group"),

  buttons: computed("currentMessage.protected", "showSolveButton", function() {
    const protect = this.get("currentMessage.protected");
    const buttons = [];

    if (!protect && this.showSolveButton) {
      buttons.push({
        klass: "solve",
        action: "solve",
        icon: "check-square-o",
        label: "Solve",
        danger: true
      });
    }

    if (this.showSolveAllButton) {
      buttons.push({
        klass: "solve-all",
        action: "solveAll",
        icon: "check-square-o",
        label: "Solve All",
        danger: true
      });
    }

    if (!protect) {
      buttons.push(
        {
          klass: "remove",
          action: "remove",
          icon: "trash-o",
          label: "Remove",
          danger: true
        },
        {
          klass: "protect",
          action: "protect",
          icon: "lock",
          label: "Protect"
        }
      );
    } else {
      buttons.push({
        klass: "unprotect",
        action: "unprotect",
        icon: "unlock",
        label: "Unprotect"
      });
    }

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

  actions: {
    tabChanged(newTab) {
      if (this.onTabChange) {
        this.onTabChange(newTab);
      }
    },

    protect() {
      this.get("currentMessage").protect();
    },

    unprotect() {
      this.get("currentMessage").unprotect();
    },

    remove() {
      this.removeMessage(this.get("currentMessage"));
    },

    solve() {
      this.solveMessage(this.get("currentMessage"));
    },

    solveAll() {
      this.currentRow.solveAll();
    },

    share() {
      window.location.pathname = this.get("currentMessage.shareUrl");
    }
  }
});

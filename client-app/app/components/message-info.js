import Component from "@ember/component";
import { computed } from "@ember/object";

export default Component.extend({
  buttons: computed("currentMessage.{canSolve,protected}", function() {
    const canSolve = this.get("currentMessage.canSolve");
    const protect = this.get("currentMessage.protected");
    const buttons = [];

    if (!protect && canSolve) {
      buttons.push({
        klass: "solve",
        action: "solve",
        icon: "check-square-o",
        label: "Solve",
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
    share() {
      window.location.pathname = this.get("currentMessage.shareUrl");
    }
  }
});

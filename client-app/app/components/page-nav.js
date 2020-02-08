import Component from "@ember/component";
import { computed } from "@ember/object";
import { equal } from "@ember/object/computed";

export default Component.extend({
  classNames: ["nav-controls"],
  classNameBindings: ["extraClasses"],
  disableBackButtons: equal("position", 0),

  disableForwardButtons: computed("position", "list.length", function() {
    return this.position === this.get("list.length") - 1;
  }),

  displayNumber: computed("position", function() {
    return this.position + 1;
  }),

  actions: {
    takeStep(dir) {
      const amount = dir === "back" ? -1 : 1;
      if (amount === 1 && this.disableForwardButtons) return;
      if (amount === -1 && this.disableBackButtons) return;

      const newPos = this.position + amount;
      this.navigate(newPos);
    },

    bigJump(dir) {
      const newPos = dir === "back" ? 0 : this.get("list.length") - 1;
      this.navigate(newPos);
    }
  }
});

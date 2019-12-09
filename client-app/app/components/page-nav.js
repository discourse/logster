import Component from "@ember/component";
import { computed, observer } from "@ember/object";
import { later } from "@ember/runloop";

export default Component.extend({
  tagName: "div",
  classNames: ["nav-controls"],
  classNameBindings: ["extraClasses"],

  didReceiveAttrs() {
    this._super(...arguments);
    later(this, () => {
      this.navigate(this.position);
    });
  },

  resetPosition: observer("resetPositionOnChange", function() {
    this.navigate(0);
  }),

  disableBackButtons: computed("position", function() {
    return this.position === 0;
  }),

  disableForwardButtons: computed("position", "list.length", function() {
    return this.position === this.get("list.length") - 1;
  }),

  displayNumber: computed("position", function() {
    return this.position + 1;
  }),

  actions: {
    takeStep(dir) {
      const amount = dir === "back" ? -1 : 1;
      const newPos = this.position + amount;
      this.navigate(newPos);
    },

    bigJump(dir) {
      const newPos = dir === "back" ? 0 : this.get("list.length") - 1;
      this.navigate(newPos);
    }
  }
});

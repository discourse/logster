import Component from '@ember/component';
import { computed } from "@ember/object";
import { buildHashString } from "client-app/lib/utilities";

export default Component.extend({
  current: 1,

  didUpdateAttrs() {
    this.set("current", 1);
  },

  isEnvArray: computed("message.env", function() {
    return Array.isArray(this.get("message.env"));
  }),

  html: computed("isEnvArray", "current", function() {
    if (!this.get("isEnvArray")) {
      return buildHashString(this.get("message.env"));
    } else {
      const currentEnv = this.get("message.env")[this.get("current") - 1];
      return buildHashString(currentEnv);
    }
  }),

  disableBackButtons: computed("current", function() {
    return this.get("current") === 1;
  }),

  disableForwardButtons: computed("current", "message.env.length", function() {
    return this.get("current") === this.get("message.env.length");
  }),

  actions: {
    takeStep(dir) {
      const amount = dir === "back" ? -1 : 1;
      this.set("current", this.get("current") + amount);
    },

    bigJump(dir) {
      const newCurrent = dir === "back" ? 1 : this.get("message.env.length");
      this.set("current", newCurrent);
    }
  }
});

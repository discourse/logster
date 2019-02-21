import Component from "@ember/component";
import { computed } from "@ember/object";
import { buildHashString } from "client-app/lib/utilities";
import Preload from "client-app/lib/preload";

export default Component.extend({
  current: 1,

  didUpdateAttrs() {
    this.setProperties({
      current: 1,
      expanded: null
    });
  },

  isEnvArray: computed("message.env", function() {
    return Array.isArray(this.get("message.env"));
  }),

  html: computed("isEnvArray", "current", "expanded.[]", function() {
    if (!this.get("isEnvArray")) {
      return buildHashString(this.get("message.env"));
    } else {
      const currentEnv = Em.$.extend(
        {},
        this.get("message.env")[this.get("current") - 1]
      );
      const expandableKeys = Preload.get("env_expandable_keys") || [];
      expandableKeys.forEach(key => {
        if (currentEnv.hasOwnProperty(key) && !Array.isArray(currentEnv[key])) {
          const list = [currentEnv[key]];
          this.get("message.env").forEach(env => {
            if (env[key] && list.indexOf(env[key]) === -1) {
              list.push(env[key]);
            }
          });
          currentEnv[key] = list.length > 1 ? list : list[0];
        }
      });
      return buildHashString(currentEnv, false, this.get("expanded") || []);
    }
  }),

  click(e) {
    const $elem = Em.$(e.target);
    const dataKey = $elem.attr("data-key");
    const expandableKeys = Preload.get("env_expandable_keys") || [];
    if (
      expandableKeys.indexOf(dataKey) !== -1 &&
      $elem.hasClass("expand-list")
    ) {
      e.preventDefault();
      if (!this.get("expanded")) {
        this.set("expanded", [dataKey]);
      } else {
        this.get("expanded").pushObject(dataKey);
      }
    }
  },

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

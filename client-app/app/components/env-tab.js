import Component from "@ember/component";
import { computed } from "@ember/object";
import { buildHashString } from "client-app/lib/utilities";
import Preload from "client-app/lib/preload";

export default Component.extend({
  didUpdateAttrs() {
    this.set("expanded", null);
  },

  currentEnv: computed("isEnvArray", "currentEnvPosition", function() {
    if (this.isEnvArray) {
      return this.message.env[this.currentEnvPosition];
    } else {
      return this.message.env;
    }
  }),

  isEnvArray: computed("message.env", function() {
    return Array.isArray(this.get("message.env"));
  }),

  html: computed("isEnvArray", "currentEnv", "expanded.[]", function() {
    if (!this.isEnvArray) {
      return buildHashString(this.get("message.env"));
    } else {
      const currentEnv = Em.$.extend({}, this.get("currentEnv"));
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
  }
});

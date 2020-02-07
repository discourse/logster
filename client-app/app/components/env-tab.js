import Component from "@ember/component";
import { computed } from "@ember/object";
import { buildHashString } from "client-app/lib/utilities";
import Preload from "client-app/lib/preload";

export default Component.extend({
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
      const expandableKeys = Preload.get("env_expandable_keys") || [];
      const expandedLists = {};
      expandableKeys.forEach(key => {
        if (
          Object.prototype.hasOwnProperty.call(this.currentEnv, key) &&
          !Array.isArray(this.currentEnv[key])
        ) {
          const list = [this.currentEnv[key]];
          this.message.env.forEach(env => {
            if (env[key] && list.indexOf(env[key]) === -1) {
              list.push(env[key]);
            }
          });
          expandedLists[key] = list;
        }
      });
      return buildHashString(
        this.currentEnv,
        false,
        this.expanded,
        expandedLists
      );
    }
  }),

  click(e) {
    const elem = e.target;
    const dataKey = elem.dataset.key;
    const expandableKeys = Preload.get("env_expandable_keys") || [];
    if (
      expandableKeys.indexOf(dataKey) !== -1 &&
      elem.classList.contains("expand-list")
    ) {
      e.preventDefault();
      if (!this.expanded) {
        this.set("expanded", [dataKey]);
      } else {
        this.expanded.pushObject(dataKey);
      }
    }
  }
});

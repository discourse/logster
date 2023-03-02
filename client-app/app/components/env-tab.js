import classic from "ember-classic-decorator";
import { computed } from "@ember/object";
import Component from "@ember/component";
import { buildHashString, clone } from "client-app/lib/utilities";
import Preload from "client-app/lib/preload";

@classic
export default class EnvTab extends Component {
  @computed("currentEnvPosition", "isEnvArray", "message.env")
  get currentEnv() {
    if (this.isEnvArray) {
      return this.message.env[this.currentEnvPosition];
    } else {
      return this.message.env;
    }
  }

  @computed("message.env")
  get isEnvArray() {
    return Array.isArray(this.get("message.env"));
  }

  @computed("currentEnv", "expanded.[]", "isEnvArray", "message.env")
  get html() {
    if (!this.isEnvArray) {
      return buildHashString(this.get("message.env"));
    } else {
      const currentEnv = clone(this.currentEnv);
      const expandableKeys = Preload.get("env_expandable_keys") || [];
      expandableKeys.forEach((key) => {
        if (currentEnv.hasOwnProperty(key) && !Array.isArray(currentEnv[key])) {
          const list = [currentEnv[key]];
          this.message.env.forEach((env) => {
            if (env[key] && list.indexOf(env[key]) === -1) {
              list.push(env[key]);
            }
          });
          currentEnv[key] = list.length > 1 ? list : list[0];
        }
      });
      return buildHashString(currentEnv, false, this.expanded || []);
    }
  }

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
}

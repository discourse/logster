import classic from "ember-classic-decorator";
import { computed } from "@ember/object";
import Component from "@ember/component";
import { buildHashString, clone } from "client-app/lib/utilities";
import Preload from "client-app/lib/preload";
import { htmlSafe } from "@ember/template";

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
    return Array.isArray(this.message.env);
  }

  @computed("currentEnv", "expanded.[]", "isEnvArray", "message.env")
  get html() {
    if (!this.isEnvArray) {
      return htmlSafe(buildHashString(this.message.env));
    }

    const currentEnv = clone(this.currentEnv);
    const expandableKeys = Preload.get("env_expandable_keys") || [];

    for (const key of expandableKeys) {
      if (
        Object.prototype.hasOwnProperty.call(currentEnv, key) &&
        !Array.isArray(currentEnv[key])
      ) {
        const list = [currentEnv[key]];
        for (const env of this.message.env) {
          if (env[key] && !list.includes(env[key])) {
            list.push(env[key]);
          }
        }
        currentEnv[key] = list.length > 1 ? list : list[0];
      }
    }

    return htmlSafe(buildHashString(currentEnv, false, this.expanded || []));
  }

  click(e) {
    const elem = e.target;
    const dataKey = elem.dataset.key;
    const expandableKeys = Preload.get("env_expandable_keys") || [];

    if (
      expandableKeys.includes(dataKey) &&
      elem.classList.contains("expand-list")
    ) {
      e.preventDefault();
      if (this.expanded) {
        this.expanded.pushObject(dataKey);
      } else {
        this.set("expanded", [dataKey]);
      }
    }
  }
}

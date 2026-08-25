import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { tracked } from "@glimmer/tracking";
import { buildHashString, clone } from "client-app/lib/utilities";
import Preload from "client-app/lib/preload";
import PageNav from "client-app/components/page-nav";

export default class EnvTab extends Component {
  @tracked expanded = [];

  get currentEnv() {
    return this.isEnvArray
      ? this.args.message.env[this.args.currentEnvPosition]
      : this.args.message.env;
  }

  get isEnvArray() {
    return Array.isArray(this.args.message.env);
  }

  get html() {
    if (!this.isEnvArray) {
      return htmlSafe(buildHashString(this.args.message.env));
    }

    const currentEnv = clone(this.currentEnv);
    const expandableKeys = Preload.get("env_expandable_keys") || [];

    for (const key of expandableKeys) {
      if (
        Object.prototype.hasOwnProperty.call(currentEnv, key) &&
        !Array.isArray(currentEnv[key])
      ) {
        const list = [currentEnv[key]];
        for (const env of this.args.message.env) {
          if (env[key] && !list.includes(env[key])) {
            list.push(env[key]);
          }
        }
        currentEnv[key] = list.length > 1 ? list : list[0];
      }
    }

    return htmlSafe(buildHashString(currentEnv, false, this.expanded));
  }

  @action
  expandValue(event) {
    const dataKey = event.target.dataset.key;
    const expandableKeys = Preload.get("env_expandable_keys") || [];

    if (
      expandableKeys.includes(dataKey) &&
      event.target.classList.contains("expand-list")
    ) {
      event.preventDefault();
      this.expanded = [...this.expanded, dataKey];
    }
  }

  <template>
    <div {{on "click" this.expandValue}} ...attributes>
      {{#if this.isEnvArray}}
        <PageNav
          @list={{@message.env}}
          @position={{@currentEnvPosition}}
          @extraClasses="env-nav"
          @navigate={{@envChangedAction}}
        />
      {{/if}}

      {{this.html}}
    </div>
  </template>
}

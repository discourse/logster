import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FaIcon from "@fortawesome/ember-fontawesome/components/fa-icon";

export default class PageNav extends Component {
  get disableBackButtons() {
    return this.args.position === 0;
  }

  get disableForwardButtons() {
    return this.args.position === this.args.list.length - 1;
  }

  get displayNumber() {
    return this.args.position + 1;
  }

  @action
  takeStep(direction) {
    const amount = direction === "back" ? -1 : 1;
    if (
      (amount === 1 && this.disableForwardButtons) ||
      (amount === -1 && this.disableBackButtons)
    ) {
      return;
    }

    this.args.navigate(this.args.position + amount);
  }

  @action
  bigJump(direction) {
    const position = direction === "back" ? 0 : this.args.list.length - 1;
    this.args.navigate(position);
  }

  <template>
    <div class="nav-controls {{@extraClasses}}" ...attributes>
      <button
        disabled={{this.disableBackButtons}}
        class="btn nav-btn no-text"
        type="button"
        {{on "click" (fn this.bigJump "back")}}
      >
        <FaIcon @icon="fast-backward" />
      </button>

      <button
        disabled={{this.disableBackButtons}}
        class="btn nav-btn no-text"
        type="button"
        {{on "click" (fn this.takeStep "back")}}
      >
        <FaIcon @icon="backward" />
      </button>

      <span class="current-number">{{this.displayNumber}}/{{@list.length}}</span>

      <button
        disabled={{this.disableForwardButtons}}
        class="btn nav-btn no-text"
        type="button"
        {{on "click" (fn this.takeStep "front")}}
      >
        <FaIcon @icon="forward" />
      </button>

      <button
        disabled={{this.disableForwardButtons}}
        class="btn nav-btn no-text"
        type="button"
        {{on "click" (fn this.bigJump "front")}}
      >
        <FaIcon @icon="fast-forward" />
      </button>
    </div>
  </template>
}

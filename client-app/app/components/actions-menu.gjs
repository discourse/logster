import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { modifier } from "ember-modifier";
import FaIcon from "@fortawesome/ember-fontawesome/components/fa-icon";

const captureElement = modifier((element, [component]) => {
  component.element = element;
  return () => (component.element = null);
});

export default class ActionsMenu extends Component {
  @tracked showMenu = false;
  element = null;

  constructor() {
    super(...arguments);
    registerDestructor(this, () => this.removeOutsideClickHandler());
  }

  @action
  outsideClickHandler(event) {
    if (this.element && !this.element.contains(event.target)) {
      this.showMenu = false;
      this.removeOutsideClickHandler();
    }
  }

  addOutsideClickHandler() {
    document.addEventListener("click", this.outsideClickHandler);
  }

  removeOutsideClickHandler() {
    document.removeEventListener("click", this.outsideClickHandler);
  }

  @action
  expandMenu(event) {
    event.stopPropagation();
    this.showMenu = !this.showMenu;

    if (this.showMenu) {
      this.addOutsideClickHandler();
    } else {
      this.removeOutsideClickHandler();
    }
  }

  <template>
    <span {{captureElement this}} ...attributes>
      {{#if @actionsInMenu}}
        {{#if this.showMenu}}
          <div class="actions-menu">
            {{yield}}
          </div>
        {{/if}}

        <button
          class="expand btn no-text"
          type="button"
          {{on "click" this.expandMenu}}
        >
          <FaIcon @icon="ellipsis-h" />
        </button>
      {{else}}
        {{yield}}
      {{/if}}

      {{#if @showShare}}
        <button class="share btn" type="button" {{on "click" @share}}>
          <FaIcon @icon="share" />
          <span>Share</span>
        </button>
      {{/if}}
    </span>
  </template>
}

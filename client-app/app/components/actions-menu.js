import Component from "@ember/component";
import { bound } from "client-app/lib/decorators";
import { action } from "@ember/object";

export default Component.extend({
  showMenu: false,
  tagName: "span",

  @bound
  outsideClickHandler(event) {
    if (
      this.element &&
      !this.element.contains(event.target) &&
      this.element !== event.target
    ) {
      this.set("showMenu", false);
      this.updateMenu();
    }
  },

  updateMenu() {
    if (this.showMenu) {
      this.addOutsideClickHandler();
    } else {
      this.removeOutsideClickHandler();
    }
  },

  addOutsideClickHandler() {
    document.addEventListener("click", this.outsideClickHandler);
  },

  removeOutsideClickHandler() {
    document.removeEventListener("click", this.outsideClickHandler);
  },

  willDestroyElement() {
    this._super(...arguments);
    this.removeOutsideClickHandler();
  },

  @action
  expandMenu() {
    this.toggleProperty("showMenu");
    this.updateMenu();
  },

  @action
  share() {
    this.share();
  },
});

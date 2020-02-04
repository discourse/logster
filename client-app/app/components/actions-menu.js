import Component from "@ember/component";

export default Component.extend({
  showMenu: false,
  tagName: "span",

  init() {
    this._super(...arguments);
    this.outsideClickHandler = this._outsideClickHandler.bind(this);
  },

  _outsideClickHandler(event) {
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

  actions: {
    expandMenu() {
      this.toggleProperty("showMenu");
      this.updateMenu();
    },
    share() {
      this.share();
    }
  }
});

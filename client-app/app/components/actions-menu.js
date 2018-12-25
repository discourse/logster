import Component from "@ember/component";
import { observer } from "@ember/object";

export default Component.extend({
  showMenu: false,
  tagName: "span",

  init() {
    this._super(...arguments);
    this.bindingFunction = this.bindingFunction.bind(this);
  },

  bindingFunction(event) {
    const context = this.$()[0];
    if (!Em.$.contains(context, event.target) && context !== event.target) {
      this.set("showMenu", false);
    }
  },

  bindDocument: observer("showMenu", function() {
    const $document = Em.$(document);
    if (this.get("showMenu")) {
      $document.on("click", this.get("bindingFunction"));
    } else {
      $document.unbind("click", this.get("bindingFunction"));
    }
  }),

  actions: {
    expandMenu() {
      this.toggleProperty("showMenu");
    },
    share() {
      this.share();
    }
  }
});

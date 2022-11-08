import Component from "@ember/component";

export default Component.extend({
  classNameBindings: ["active", ":content", "name"],
  isLink: false,

  invokeParent(name) {
    let current = this.parentView;
    while (current && !current[name]) {
      current = current.get("parentView");
    }
    if (current) {
      current[name](this);
    }
  },

  didInsertElement() {
    this._super(...arguments);
    this.invokeParent("addTab");
    if (this.defaultTab) {
      this.invokeParent("selectTab");
    }
  },

  willDestroyElement() {
    this._super(...arguments);
    this.invokeParent("removeTab");
  },
});

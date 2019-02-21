import Component from "@ember/component";

export default Component.extend({
  classNameBindings: ["active", ":content", "name"],
  isLink: false,

  invokeParent(name) {
    let current = this.get("parentView");
    while (current && !current[name]) {
      current = current.get("parentView");
    }
    if (current) {
      current[name](this);
    }
  },

  didInsertElement() {
    this.invokeParent("addTab");
    if (this.get("defaultTab")) {
      this.invokeParent("selectTab");
    }
  },

  willDestroyElement() {
    this.invokeParent("removeTab");
  }
});

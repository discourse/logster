import Component from "@ember/component";

export default Component.extend({
  tabs: Em.A(),
  selectTab(view) {
    if (view.get("isLink")) {
      this.triggerAction(view.get("action"));
      return;
    }

    const selected = this.get("selected");
    if (selected) {
      selected.set("active", false);
    }
    this.set("selected", view);
    view.set("active", true);
    this.onTabChange(view.name);
  },

  addTab(tab) {
    this.get("tabs").addObject(tab);
    if (!this.get("selected") && !tab.get("isLink")) {
      this.selectTab(tab);
    }
  },

  removeTab(tab) {
    if (this.get("selected") === tab) {
      this.set("selected", null);
    }
    this.get("tabs").removeObject(tab);
  }
});

import Component from "@ember/component";

export default Component.extend({
  tabs: Em.A(),
  selectTab(view) {
    if (view.get("isLink")) {
      this.triggerAction(view.get("action"));
      return;
    }

    const selected = this.selected;
    if (selected) {
      selected.set("active", false);
    }
    this.set("selected", view);
    view.set("active", true);
    this.onTabChange(view.name);
  },

  addTab(tab) {
    this.tabs.addObject(tab);
    if (!this.selected && !tab.get("isLink")) {
      this.selectTab(tab);
    }
  },

  removeTab(tab) {
    if (this.selected === tab) {
      this.set("selected", null);
    }
    this.tabs.removeObject(tab);
  },
});

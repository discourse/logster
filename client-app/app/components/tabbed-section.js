import classic from "ember-classic-decorator";
import Component from "@ember/component";
import { A } from "@ember/array";
import { action } from "@ember/object";

@classic
export default class TabbedSection extends Component {
  tabs = A();
  selected = null;

  @action
  selectTab(tab) {
    if (tab.isLink) {
      this.triggerAction(tab.action);
      return;
    }

    if (this.selected) {
      this.selected.set("active", false);
    }

    this.set("selected", tab);
    tab.set("active", true);

    this.onTabChange(tab.name);
  }

  @action
  addTab(tab) {
    this.tabs.addObject(tab);

    if (!this.selected && !tab.isLink) {
      this.selectTab(tab);
    }
  }

  @action
  removeTab(tab) {
    if (this.selected === tab) {
      this.set("selected", null);
    }

    this.tabs.removeObject(tab);
  }
}

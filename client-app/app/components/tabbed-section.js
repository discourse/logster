import classic from "ember-classic-decorator";
import Component from "@ember/component";
import { A } from "@ember/array";
import { action } from "@ember/object";

@classic
export default class TabbedSection extends Component {
  tabs = A();
  selected = null;

  @action
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
  }

  @action
  addTab(tab) {
    this.tabs.addObject(tab);

    if (!this.selected && !tab.get("isLink")) {
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

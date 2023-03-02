import classic from "ember-classic-decorator";
import { classNameBindings } from "@ember-decorators/component";
import Component from "@ember/component";

@classic
@classNameBindings("active", ":content", "name")
export default class TabContents extends Component {
  isLink = false;

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.invokeParent("addTab");
    if (this.defaultTab) {
      this.invokeParent("selectTab");
    }
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this.invokeParent("removeTab");
  }

  invokeParent(name) {
    let current = this.parentView;
    while (current && !current[name]) {
      current = current.get("parentView");
    }
    if (current) {
      current[name](this);
    }
  }
}

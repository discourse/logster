import classic from "ember-classic-decorator";
import { classNameBindings } from "@ember-decorators/component";
import Component from "@ember/component";

@classic
@classNameBindings("active", ":content", "name")
export default class TabContents extends Component {
  isLink = false;

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.tabActions.addTab(this);

    if (this.defaultTab) {
      this.tabActions.selectTab(this);
    }
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this.tabActions.removeTab(this);
  }
}

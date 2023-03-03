import classic from "ember-classic-decorator";
import { classNameBindings, classNames } from "@ember-decorators/component";
import { equal } from "@ember/object/computed";
import Component from "@ember/component";
import { action, computed } from "@ember/object";

@classic
@classNames("nav-controls")
@classNameBindings("extraClasses")
export default class PageNav extends Component {
  @equal("position", 0) disableBackButtons;

  @computed("position", "list.length")
  get disableForwardButtons() {
    return this.position === this.list.length - 1;
  }

  @computed("position")
  get displayNumber() {
    return this.position + 1;
  }

  @action
  takeStep(dir) {
    const amount = dir === "back" ? -1 : 1;
    if (amount === 1 && this.disableForwardButtons) {
      return;
    }
    if (amount === -1 && this.disableBackButtons) {
      return;
    }

    const newPos = this.position + amount;
    this.navigate(newPos);
  }

  @action
  bigJump(dir) {
    const newPos = dir === "back" ? 0 : this.list.length - 1;
    this.navigate(newPos);
  }
}

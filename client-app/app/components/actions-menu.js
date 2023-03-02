import classic from "ember-classic-decorator";
import { tagName } from "@ember-decorators/component";
import Component from "@ember/component";
import { bound } from "client-app/lib/decorators";
import { action } from "@ember/object";

@classic
@tagName("span")
export default class ActionsMenu extends Component {
  showMenu = false;

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this.removeOutsideClickHandler();
  }

  @bound
  outsideClickHandler(event) {
    if (
      this.element &&
      !this.element.contains(event.target) &&
      this.element !== event.target
    ) {
      this.set("showMenu", false);
      this.updateMenu();
    }
  }

  updateMenu() {
    if (this.showMenu) {
      this.addOutsideClickHandler();
    } else {
      this.removeOutsideClickHandler();
    }
  }

  addOutsideClickHandler() {
    document.addEventListener("click", this.outsideClickHandler);
  }

  removeOutsideClickHandler() {
    document.removeEventListener("click", this.outsideClickHandler);
  }

  @action
  expandMenu() {
    this.toggleProperty("showMenu");
    this.updateMenu();
  }
}

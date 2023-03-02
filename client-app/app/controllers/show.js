import classic from "ember-classic-decorator";
import Controller from "@ember/controller";
import { action } from "@ember/object";

@classic
export default class ShowController extends Controller {
  envPosition = 0;

  @action
  protect() {
    this.model.protect();
  }

  @action
  unprotect() {
    this.model.unprotect();
  }

  @action
  envChanged(newPosition) {
    this.set("envPosition", newPosition);
  }
}

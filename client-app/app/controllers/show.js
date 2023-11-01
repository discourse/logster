import classic from "ember-classic-decorator";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { inject as controller } from "@ember/controller";

@classic
export default class ShowController extends Controller {
  @service router;
  @controller("index") indexController;

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
  async solveMessage(msg) {
    await msg.solve();
    this.router.transitionTo("index");
  }

  @action
  async removeMessage(msg) {
    await msg.destroy();
    this.router.transitionTo("index");
  }

  @action
  envChanged(newPosition) {
    this.set("envPosition", newPosition);
  }
}

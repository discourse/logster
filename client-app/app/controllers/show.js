import Controller from "@ember/controller";
import { action } from "@ember/object";

export default Controller.extend({
  envPosition: 0,

  @action
  protect() {
    this.model.protect();
  },

  @action
  unprotect() {
    this.model.unprotect();
  },

  @action
  envChanged(newPosition) {
    this.set("envPosition", newPosition);
  },
});

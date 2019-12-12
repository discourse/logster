import Controller from "@ember/controller";

export default Controller.extend({
  envPosition: 0,

  actions: {
    protect() {
      this.get("model").protect();
    },

    unprotect() {
      this.get("model").unprotect();
    },

    envChanged(newPosition) {
      this.set("envPosition", newPosition);
    }
  }
});

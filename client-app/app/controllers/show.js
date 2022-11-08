import Controller from "@ember/controller";

export default Controller.extend({
  envPosition: 0,

  actions: {
    protect() {
      this.model.protect();
    },

    unprotect() {
      this.model.unprotect();
    },

    envChanged(newPosition) {
      this.set("envPosition", newPosition);
    },
  },
});

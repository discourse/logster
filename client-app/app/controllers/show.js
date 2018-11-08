import Controller from "@ember/controller";

export default Controller.extend({
  actions: {
    protect() {
      this.get("model").protect();
    },

    unprotect() {
      this.get("model").unprotect();
    }
  }
});

import Component from "@ember/component";

export default Component.extend({
  actions: {
    protect() {
      this.get("currentMessage").protect();
    },
    unprotect() {
      this.get("currentMessage").unprotect();
    },
    remove() {
      this.removeMessage(this.get("currentMessage"));
    },
    solve() {
      this.solveMessage(this.get("currentMessage"));
    }
  }
});

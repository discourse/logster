import Controller from "@ember/controller";
import { ajax } from "client-app/lib/utilities";
import { observer } from "@ember/object";

export default Controller.extend({
  currentMessage: Em.computed.alias("model.currentMessage"),

  actions: {
    expandMessage(message) {
      message.expand();
    },

    selectMessage(message) {
      const old = this.get("currentMessage");
      if (old) {
        old.set("selected", false);
      }

      message.set("selected", true);
      this.set("currentMessage", message);
    },

    showMoreBefore() {
      this.get("model").showMoreBefore();
    },

    loadMore() {
      return this.get("model").loadMore();
    },

    clear() {
      if (confirm("Clear the logs?\n\nCancel = No, OK = Clear")) {
        ajax("/clear", { type: "POST" }).then(() => {
          this.get("model").reload();
        });
      }
    },

    removeMessage(msg) {
      const messages = this.get("model");
      messages.destroy(msg);
    },

    solveMessage(msg) {
      const messages = this.get("model");
      messages.solve(msg);
    }
  },

  filterChanged: observer(
    "showDebug",
    "showInfo",
    "showWarn",
    "showErr",
    "showFatal",
    function() {
      const filter = [];
      ["Debug", "Info", "Warn", "Err", "Fatal"].forEach((severity, index) => {
        if (this.get(`show${severity}`)) {
          filter.push(index);
        }
      });

      // always show unknown, rare
      filter.push(5);
      const model = this.get("model");
      model.set("filter", filter);
      if (this.get("initialized")) {
        model.reload();
      }
    }
  ),

  searchChanged: observer("search", function() {
    const search = this.get("search");
    const model = this.get("model");
    model.set("search", search);

    if (this.get("initialized")) {
      model.reload();
    }
  })
});

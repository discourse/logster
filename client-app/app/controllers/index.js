import Controller from "@ember/controller";
import { ajax } from "client-app/lib/utilities";
import { observer, computed } from "@ember/object";
import Preload from "client-app/lib/preload";
import { debounce } from "@ember/runloop";

export default Controller.extend({
  showDebug: true,
  showInfo: true,
  showWarn: true,
  showErr: true,
  showFatal: true,
  search: "",
  currentMessage: Em.computed.alias("model.currentMessage"),

  showSettings: computed(function() {
    return Preload.get("patterns_enabled");
  }),

  resizePanels(amount) {
    Em.$("#bottom-panel").css("height", amount - 13);
    Em.$("#top-panel").css("bottom", amount + 12);
  },

  actionsInMenu: computed(function() {
    return this.site.isMobile;
  }),

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

  updateSelectedMessage() {
    const currentKey = this.get("currentMessage.key");
    const messages = this.get("model.messages");
    if (currentKey && messages) {
      const match = messages.find(m => m.key === currentKey);
      if (match) {
        match.set("selected", true);
      } else {
        this.set("currentMessage", null);
      }
    }
  },

  filter: computed(
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
      return filter;
    }
  ),

  filterChanged: observer("filter.length", function() {
    const filter = this.get("filter");
    const model = this.get("model");
    model.set("filter", filter);
    if (filter && this.get("initialized")) {
      model.reload().then(() => this.updateSelectedMessage());
    }
  }),

  doSearch() {
    const search = this.get("search");
    const model = this.get("model");
    model.set("search", search);

    if (this.get("initialized")) {
      model.reload().then(() => this.updateSelectedMessage());
    }
  },

  searchChanged: observer("search", function() {
    debounce(this, this.doSearch, 250);
  })
});

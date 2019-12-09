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
  queryParams: ["search"],

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

    selectRowAction(row, opts = {}) {
      this.model.selectRow(row, opts);
    },

    tabChangedAction(newTab) {
      this.model.tabChanged(newTab);
    },

    showMoreBefore() {
      this.model.showMoreBefore();
    },

    loadMore() {
      return this.model.loadMore();
    },

    clear() {
      if (confirm("Clear the logs?\n\nCancel = No, OK = Clear")) {
        ajax("/clear", { type: "POST" }).then(() => {
          this.model.reload();
        });
      }
    },

    removeMessage(msg) {
      const group = this.model.currentRow.group ? this.model.currentRow : null;
      const rows = this.model.rows;
      const idx = group ? rows.indexOf(group) : rows.indexOf(msg);

      msg.destroy();
      msg.set("selected", false);
      this.model.set("total", this.model.total - 1);
      let removedRow = false;

      if (group) {
        group.messages.removeObject(msg);
        group.set("count", group.count - 1);
        if (group.count === 0) {
          rows.removeObject(group);
          removedRow = true;
        }
      } else {
        rows.removeObject(msg);
        removedRow = true;
      }

      if (removedRow) {
        if (idx > 0) {
          this.model.selectRow(rows[idx - 1]);
        } else if (this.model.total > 0) {
          this.model.selectRow(rows[0]);
        } else {
          this.model.reload();
        }
      }
    },

    solveMessage(msg) {
      this.model.solve(msg);
    },

    groupedMessageChangedAction(newPosition) {
      this.model.groupedMessageChanged(newPosition);
    },

    envChangedAction(newPosition) {
      this.model.envChanged(newPosition);
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
    this.model.set("filter", filter);
    if (filter && this.get("initialized")) {
      this.model.reload().then(() => this.model.updateSelectedRow());
    }
  }),

  doSearch(term) {
    this.model.set("search", term);

    if (this.get("initialized")) {
      this.model.reload().then(() => this.model.updateSelectedRow());
    }
  },

  searchChanged: observer("search", function() {
    const term = this.search;
    const termSize = term && term.length;
    if (termSize && termSize === 1) {
      return;
    }
    debounce(this, this.doSearch, term, 250);
  })
});

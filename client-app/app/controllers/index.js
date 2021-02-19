import Controller from "@ember/controller";
import {
  ajax,
  getLocalStorage,
  setLocalStorage
} from "client-app/lib/utilities";
import { computed } from "@ember/object";
import Preload from "client-app/lib/preload";
import { debounce } from "@ember/runloop";

export default Controller.extend({
  showDebug: getLocalStorage("showDebug", false),
  showInfo: getLocalStorage("showInfo", false),
  showWarn: getLocalStorage("showWarn", true),
  showErr: getLocalStorage("showErr", true),
  showFatal: getLocalStorage("showFatal", true),
  search: "",
  queryParams: ["search"],

  showSettings: computed(function() {
    return Preload.get("patterns_enabled");
  }),

  resizePanels(amount) {
    const bottomPanel = document.getElementById("bottom-panel");
    const topPanel = document.getElementById("top-panel");
    bottomPanel.style.height = `${amount - 13}px`;
    topPanel.style.bottom = `${amount + 12}px`;
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
      let messageIndex = 0;

      if (group) {
        messageIndex = group.messages.indexOf(msg);
        group.messages.removeObject(msg);
        messageIndex = Math.min(messageIndex, group.messages.length - 1);
        if (group.messages.length === 0) {
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
      } else if (group) {
        this.model.selectRow(rows[idx], { messageIndex });
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
    },

    updateFilter(name) {
      this.toggleProperty(name);
      this.model.set(name, this[name]);
      setLocalStorage(name, this[name]);
      this.model.reload().then(() => this.model.updateSelectedRow());
    },

    updateSearch(term) {
      if (term === this.search) {
        return;
      }

      if (term && term.length === 1) {
        return;
      }

      debounce(this, this.doSearch, term, 250);
    }
  },

  doSearch(term) {
    this.model.set("search", term);
    this.model.reload().then(() => this.model.updateSelectedRow());
  }
});

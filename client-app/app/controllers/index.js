import classic from "ember-classic-decorator";
import { debounce } from "@ember/runloop";
import { action, computed } from "@ember/object";
import Controller from "@ember/controller";
import {
  ajax,
  getLocalStorage,
  setLocalStorage,
} from "client-app/lib/utilities";
import Preload from "client-app/lib/preload";

@classic
export default class IndexController extends Controller {
  showDebug = getLocalStorage("showDebug", false);
  showInfo = getLocalStorage("showInfo", false);
  showWarn = getLocalStorage("showWarn", true);
  showErr = getLocalStorage("showErr", true);
  showFatal = getLocalStorage("showFatal", true);
  search = null;
  queryParams = ["search"];

  @computed
  get showSettings() {
    return Preload.get("patterns_enabled");
  }

  get actionsInMenu() {
    return (
      /mobile/i.test(navigator.userAgent) && !/iPad/.test(navigator.userAgent)
    );
  }

  @computed("search")
  get searchTerm() {
    if (this.search) {
      this.doSearch(this.search);
      return this.search;
    }
    return null;
  }

  doSearch(term) {
    this.model.set("search", term);
    this.model.reload().then(() => this.model.updateSelectedRow());
  }

  resizePanels(amount) {
    const bottomPanel = document.getElementById("bottom-panel");
    const topPanel = document.getElementById("top-panel");
    bottomPanel.style.height = `${amount - 13}px`;
    topPanel.style.bottom = `${amount + 12}px`;
  }

  @action
  expandMessage(message) {
    message.expand();
  }

  @action
  selectRowAction(row, opts = {}) {
    this.model.selectRow(row, opts);
  }

  @action
  tabChangedAction(newTab) {
    this.model.tabChanged(newTab);
  }

  @action
  showMoreBefore() {
    this.model.showMoreBefore();
  }

  @action
  loadMore() {
    return this.model.loadMore();
  }

  @action
  clear() {
    if (confirm("Clear the logs?\n\nCancel = No, OK = Clear")) {
      ajax("/clear", { type: "POST" }).then(() => {
        this.model.reload();
      });
    }
  }

  @action
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
  }

  @action
  solveMessage(msg) {
    this.model.solve(msg);
  }

  @action
  groupedMessageChangedAction(newPosition) {
    this.model.groupedMessageChanged(newPosition);
  }

  @action
  envChangedAction(newPosition) {
    this.model.envChanged(newPosition);
  }

  @action
  updateFilter(name) {
    this.toggleProperty(name);
    this.model.set(name, this[name]);
    setLocalStorage(name, this[name]);
    this.model.reload().then(() => this.model.updateSelectedRow());
  }

  @action
  updateSearch(event) {
    const term = event.target.value;

    if (term === this.search) {
      return;
    }

    if (term && term.length === 1) {
      return;
    }

    debounce(this, this.doSearch, term, 250);
  }
}

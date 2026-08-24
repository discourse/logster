import { debounce } from "@ember/runloop";
import { action } from "@ember/object";
import Controller from "@ember/controller";
import {
  ajax,
  getLocalStorage,
  setLocalStorage,
} from "client-app/lib/utilities";
import Preload from "client-app/lib/preload";
import { tracked } from "@glimmer/tracking";

const MAX_GROUPING_PATTERN_LENGTH = 480;
const MAX_GROUPING_PATTERN_INSPECT_SIZE = 490;
const MAX_GROUPING_ALTERNATIVE_LENGTH = 200;

export default class IndexController extends Controller {
  @tracked loading = false;
  @tracked buildingGroupingPattern = false;
  @tracked rowMessagesForGroupingPattern = [];
  @tracked showGroupingPatternDialog = false;
  @tracked groupingPatternError = null;
  @tracked groupingPatternSaving = false;
  @tracked groupingPatternValue = "";

  @tracked showDebug = getLocalStorage("showDebug", false);
  @tracked showInfo = getLocalStorage("showInfo", false);
  @tracked showWarn = getLocalStorage("showWarn", true);
  @tracked showErr = getLocalStorage("showErr", true);
  @tracked showFatal = getLocalStorage("showFatal", true);
  @tracked search = null;
  queryParams = ["search"];

  get showSettings() {
    return Preload.get("patterns_enabled");
  }

  get backToSiteLinkText() {
    return Preload.get("back_to_site_link_text");
  }

  get backToSiteLinkPath() {
    return Preload.get("back_to_site_link_path");
  }

  get hasTopMenu() {
    return this.backToSiteLinkText && this.backToSiteLinkPath;
  }

  get actionsInMenu() {
    return (
      /mobile/i.test(navigator.userAgent) && !/iPad/.test(navigator.userAgent)
    );
  }

  get showCreateGroupingPattern() {
    return (
      this.buildingGroupingPattern &&
      this.rowMessagesForGroupingPattern.length > 1
    );
  }

  get searchTerm() {
    return this.search;
  }

  doSearch(term) {
    this.search = term || null;
  }

  resizePanels(amount) {
    const bottomPanel = document.getElementById("bottom-panel");
    const topPanel = document.getElementById("top-panel");
    bottomPanel.style.height = `${amount - 13}px`;
    topPanel.style.bottom = `${amount + 12}px`;
  }

  request(url, settings) {
    return ajax(url, settings);
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
  handleCheckboxChange(row, event) {
    const messages = this.groupingMessagesForRow(row);

    if (event.target.checked) {
      this.rowMessagesForGroupingPattern = [
        ...new Set([...this.rowMessagesForGroupingPattern, ...messages]),
      ];
    } else {
      this.rowMessagesForGroupingPattern =
        this.rowMessagesForGroupingPattern.filter(
          (message) => !messages.includes(message)
        );
    }
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
  async clear() {
    // eslint-disable-next-line no-alert
    if (confirm("Clear the logs?\n\nCancel = No, OK = Clear")) {
      await ajax("/clear", { type: "POST" });
      this.model.reload();
      this.loading = false;
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
  async updateFilter(name) {
    this[name] = !this[name];
    this.model.set(name, this[name]);
    setLocalStorage(name, this[name]);
    this.loading = true;
    await this.model.reload();
    this.loading = false;
    this.model.updateSelectedRow();
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

  @action
  toggleGroupingPatternFromSelectedRows() {
    this.buildingGroupingPattern = !this.buildingGroupingPattern;
    this.rowMessagesForGroupingPattern = [];
  }

  @action
  createGroupingPatternFromSelectedRows() {
    this.groupingPatternValue = this.buildGroupingPatternSuggestion(
      this.rowMessagesForGroupingPattern
    );
    this.groupingPatternError = null;
    this.showGroupingPatternDialog = true;
  }

  @action
  updateGroupingPatternValue(event) {
    this.groupingPatternValue = event.target.value;
    this.groupingPatternError = null;
  }

  @action
  async confirmGroupingPattern() {
    const pattern = this.groupingPatternValue.trim();
    if (!pattern.length || this.groupingPatternSaving) {
      return;
    }

    this.groupingPatternSaving = true;
    this.groupingPatternError = null;

    try {
      await this.request("/patterns/grouping.json", {
        method: "POST",
        data: { pattern },
      });
      this.showGroupingPatternDialog = false;
      this.groupingPatternValue = "";
      this.rowMessagesForGroupingPattern = [];
      this.buildingGroupingPattern = false;
      this.model.reload();
    } catch (response) {
      this.groupingPatternError =
        response.responseText ||
        response.message ||
        "Unable to create the grouping pattern.";
    } finally {
      this.groupingPatternSaving = false;
    }
  }

  @action
  cancelGroupingPattern() {
    this.showGroupingPatternDialog = false;
    this.groupingPatternError = null;
    this.groupingPatternValue = "";
  }

  groupingMessagesForRow(row) {
    const messages = row.group
      ? row.messages.map((message) => message.message)
      : [row.message || row.displayMessage];

    return messages.filter(
      (message) => typeof message === "string" && message.trim().length > 0
    );
  }

  buildGroupingPatternSuggestion(strings) {
    const messages = [...new Set(strings)].filter(
      (message) => typeof message === "string" && message.trim().length > 0
    );
    const commonText = this.findLongestMatchingPrefix(messages);

    if (commonText.trim().length >= 3) {
      return this.escapeRegExpPrefix(
        commonText,
        MAX_GROUPING_PATTERN_LENGTH,
        (pattern) =>
          this.estimatedRubyRegexpInspectSize(pattern) <=
          MAX_GROUPING_PATTERN_INSPECT_SIZE
      );
    }

    const alternatives = [];
    let patternLength = 4; // `(?:` and `)`

    for (const message of messages) {
      const separatorLength = alternatives.length > 0 ? 1 : 0;
      const availableLength =
        MAX_GROUPING_PATTERN_LENGTH - patternLength - separatorLength;
      const alternative = this.escapeRegExpPrefix(
        message.trim().slice(0, MAX_GROUPING_ALTERNATIVE_LENGTH),
        availableLength,
        (value) => {
          const candidate = `(?:${[...alternatives, value].join("|")})`;
          return (
            this.estimatedRubyRegexpInspectSize(candidate) <=
            MAX_GROUPING_PATTERN_INSPECT_SIZE
          );
        }
      );

      if (!alternative.length) {
        break;
      }

      alternatives.push(alternative);
      patternLength += separatorLength + alternative.length;
    }

    return `(?:${alternatives.join("|")})`;
  }

  escapeRegExpPrefix(string, maximumLength, valid = () => true) {
    let result = "";

    for (const character of string) {
      const escapedCharacter = this.escapeRegExp(character);
      const candidate = result + escapedCharacter;
      if (candidate.length > maximumLength || !valid(candidate)) {
        break;
      }
      result = candidate;
    }

    return result;
  }

  estimatedRubyRegexpInspectSize(pattern) {
    let size = 2; // leading and trailing `/`

    for (const character of pattern) {
      const codepoint = character.codePointAt(0);
      if (character === "\\" || character === "/") {
        size += 2;
      } else if (codepoint < 0x20 || codepoint === 0x7f) {
        size += 4; // conservatively allow for Ruby's `\\xNN` representation
      } else {
        size += 1;
      }
    }

    return size;
  }

  findLongestMatchingPrefix(strings) {
    if (strings.length === 0) {
      return "";
    }

    const shortestString = strings.reduce(
      (shortest, str) => (str.length < shortest.length ? str : shortest),
      strings[0]
    );

    let longestMatchingSubstring = "";
    for (let i = 0; i < shortestString.length; i++) {
      const currentSubstring = shortestString.substring(0, i + 1);

      if (strings.every((str) => str.includes(currentSubstring))) {
        longestMatchingSubstring = currentSubstring;
      } else {
        break;
      }
    }

    return longestMatchingSubstring;
  }

  escapeRegExp(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); // $& means the whole matched string
  }
}

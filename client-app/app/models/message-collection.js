import classic from "ember-classic-decorator";
import { ajax, increaseTitleCount } from "client-app/lib/utilities";
import Message from "client-app/models/message";
import Group from "client-app/models/group";
import { compare } from "@ember/utils";
import EmberObject, { computed } from "@ember/object";
import { A } from "@ember/array";

const BATCH_SIZE = 50;
export const SEVERITIES = ["Debug", "Info", "Warn", "Err", "Fatal"];

@classic
export default class MessageCollection extends EmberObject {
  total = 0;
  rows = A();
  currentRow = null;
  currentTab = null;
  currentEnvPosition = 0;
  currentGroupedMessagesPosition = 0;
  search = "";

  @computed(...SEVERITIES.map((s) => `show${s}`))
  get filter() {
    const filter = [];
    SEVERITIES.forEach((severity, index) => {
      if (this[`show${severity}`]) {
        filter.push(index);
      }
    });
    filter.push(5); // always show unknown, rare
    return filter;
  }

  @computed("currentRow", "currentGroupedMessagesPosition")
  get currentMessage() {
    const row = this.currentRow;
    const position = this.currentGroupedMessagesPosition;
    if (row && row.group) {
      return row.messages[position];
    } else {
      return row;
    }
  }

  @computed("filter", "search.length")
  get hideCountInLoadMore() {
    const filter = this.filter;
    return (
      (this.search && this.search.length > 0) || (filter && filter.length < 6)
    );
  }

  @computed("rows.length", "canLoadMore")
  get moreBefore() {
    return this.rows.length >= BATCH_SIZE && this.canLoadMore;
  }

  @computed("total", "rows.length")
  get totalBefore() {
    return this.total - this.rows.length;
  }

  @computed("search")
  get regexSearch() {
    const search = this.search;
    if (search && search.length > 2 && search[0] === "/") {
      const match = search.match(/\/(.*)\/(.*)/);
      if (match && match.length === 3) {
        try {
          return new RegExp(match[1], match[2]);
        } catch (err) {
          // don't care
        }
      }
    }
    return null;
  }

  async solve(message) {
    await message.solve();
    this.reload();
  }

  selectRow(row, opts = {}) {
    const old = this.currentRow;
    if (old) {
      old.set("selected", false);
    }
    row.set("selected", true);
    const currentGroupedMessagesPosition = opts["messageIndex"] || 0;
    const shouldRefresh =
      currentGroupedMessagesPosition === this.currentGroupedMessagesPosition;
    this.setProperties({
      currentRow: row,
      loadingEnv: false,
      currentGroupedMessagesPosition,
      currentEnvPosition: 0,
    });
    if (shouldRefresh) {
      this.notifyPropertyChange("currentGroupedMessagesPosition");
    }
    const forceFetchEnv = this.currentMessage && !this.currentMessage.env;
    this.fetchEnv({ force: forceFetchEnv });
  }

  tabChanged(newTab) {
    this.setProperties({
      currentTab: newTab,
      loadingEnv: false,
    });
    this.fetchEnv();
  }

  groupedMessageChanged(newPosition) {
    this.setProperties({
      currentGroupedMessagesPosition: newPosition,
      currentEnvPosition: 0,
    });
    const forceFetchEnv = this.currentMessage && !this.currentMessage.env;
    this.fetchEnv({ force: forceFetchEnv });
  }

  envChanged(newPosition) {
    this.set("currentEnvPosition", newPosition);
    this.fetchEnv();
  }

  fetchEnv(opts = {}) {
    const message = this.currentMessage;
    if (
      opts["force"] ||
      (message && !message.env && this.currentTab === "env")
    ) {
      this.set("loadingEnv", true);
      return message.fetchEnv().finally(() => this.set("loadingEnv", false));
    }
  }

  findEquivalentMessageIndex(row) {
    let messageIndex = 0;
    if (
      row?.group &&
      this.currentRow?.group &&
      row.key === this.currentRow.key
    ) {
      messageIndex = row.messages.mapBy("key").indexOf(this.currentMessage.key);
      messageIndex = Math.max(0, messageIndex);
    }

    return messageIndex;
  }

  updateSelectedRow() {
    const currentKey = this.currentRow?.key;

    if (currentKey && this.rows) {
      const match = this.rows.find((m) => m.key === currentKey);
      if (match) {
        const messageIndex = this.findEquivalentMessageIndex(match);
        this.selectRow(match, { messageIndex });
      } else {
        this.setProperties({
          currentRow: null,
          currentEnvPosition: 0,
          currentGroupedMessagesPosition: 0,
        });
      }
    }
  }

  async load(opts) {
    opts ||= {};

    const data = {
      filter: this.filter.join("_"),
    };

    if (this.search && this.search.length > 0) {
      data.search = this.search;
      const regexSearch = this.regexSearch;
      if (regexSearch) {
        data.regex_search = "true";
      }
    }

    if (opts.before) {
      data.before = opts.before;
      if (opts.knownGroups) {
        data.known_groups = opts.knownGroups;
      }
    }

    if (opts.after) {
      data.after = opts.after;
    }

    this.set("loading", true);

    try {
      const response = await ajax("/messages.json", {
        data,
        method: "POST",
      });

      // guard against race: ensure the results we're trying to apply
      //                     match the current search terms
      if (compare(response.filter, this.filter) !== 0) {
        return;
      }

      if (compare(response.search, this.search) !== 0) {
        return;
      }

      if (response.messages.length > 0) {
        const newRows = this.toObjects(response.messages);

        if (opts.before) {
          this.rows.unshiftObjects(newRows);
        } else {
          for (const newRow of newRows) {
            for (const row of this.rows) {
              if (row.key !== newRow.key) {
                continue;
              }

              this.rows.removeObject(row);

              if (this.currentRow === row) {
                const messageIndex = this.findEquivalentMessageIndex(newRow);
                this.selectRow(newRow, { messageIndex });
              }
            }
          }

          this.rows.addObjects(newRows);

          if (newRows.length > 0) {
            increaseTitleCount(newRows.length);
          }
        }
      }

      this.set("total", response.total);
      return response;
    } finally {
      this.set("loading", false);
    }
  }

  async reload() {
    this.set("total", 0);
    this.rows.clear();

    const data = await this.load();
    this.updateCanLoadMore(data);
  }

  updateCanLoadMore(data) {
    if (!data) {
      return;
    }

    if (data.messages.length < BATCH_SIZE) {
      this.set("canLoadMore", false);
    } else {
      this.set("canLoadMore", true);
    }
  }

  loadMore() {
    if (this.rows.length === 0) {
      this.load({});
      return;
    }

    const lastLog = this.rows[this.rows.length - 1];
    const lastKey = lastLog.group ? lastLog.row_id : lastLog.key;

    this.load({
      after: lastKey,
    });
  }

  async showMoreBefore() {
    const firstLog = this.rows[0];
    const firstKey = firstLog.group ? firstLog.row_id : firstLog.key;
    const knownGroups = this.rows.filterBy("group").mapBy("regex");

    const data = await this.load({
      before: firstKey,
      knownGroups,
    });

    this.updateCanLoadMore(data);
  }

  toObjects(rows) {
    return rows.map((m) => {
      return m.group ? Group.create(m) : Message.create(m);
    });
  }
}

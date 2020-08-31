import { ajax, increaseTitleCount } from "client-app/lib/utilities";
import Message from "client-app/models/message";
import Group from "client-app/models/group";
import { compare } from "@ember/utils";
import { default as EmberObject, computed } from "@ember/object";
import { A } from "@ember/array";

const BATCH_SIZE = 50;

export const SEVERITIES = ["Debug", "Info", "Warn", "Err", "Fatal"];

export default EmberObject.extend({
  total: 0,
  rows: null,
  currentRow: null,
  currentTab: null,
  currentEnvPosition: 0,
  currentGroupedMessagesPosition: 0,

  filter: computed(...SEVERITIES.map(s => `show${s}`), function() {
    const filter = [];
    SEVERITIES.forEach((severity, index) => {
      if (this[`show${severity}`]) {
        filter.push(index);
      }
    });
    filter.push(5); // always show unknown, rare
    return filter;
  }),

  init() {
    this._super(...arguments);
    this.setProperties({
      search: "",
      rows: A()
    });
  },

  currentMessage: computed(
    "currentRow",
    "currentGroupedMessagesPosition",
    function() {
      const row = this.currentRow;
      const position = this.currentGroupedMessagesPosition;
      if (row && row.group) {
        return row.messages[position];
      } else {
        return row;
      }
    }
  ),

  solve(message) {
    message.solve().then(() => {
      this.reload();
    });
  },

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
      currentEnvPosition: 0
    });
    if (shouldRefresh)
      this.notifyPropertyChange("currentGroupedMessagesPosition");
    const forceFetchEnv = this.currentMessage && !this.currentMessage.env;
    this.fetchEnv({ force: forceFetchEnv });
  },

  tabChanged(newTab) {
    this.setProperties({
      currentTab: newTab,
      loadingEnv: false
    });
    this.fetchEnv();
  },

  groupedMessageChanged(newPosition) {
    this.setProperties({
      currentGroupedMessagesPosition: newPosition,
      currentEnvPosition: 0
    });
    const forceFetchEnv = this.currentMessage && !this.currentMessage.env;
    this.fetchEnv({ force: forceFetchEnv });
  },

  envChanged(newPosition) {
    this.set("currentEnvPosition", newPosition);
    this.fetchEnv();
  },

  fetchEnv(opts = {}) {
    const message = this.currentMessage;
    if (
      opts["force"] ||
      (message && !message.env && this.currentTab === "env")
    ) {
      this.set("loadingEnv", true);
      return message.fetchEnv().finally(() => this.set("loadingEnv", false));
    }
  },

  findEquivalentMessageIndex(row) {
    let messageIndex = 0;
    if (
      row &&
      row.group &&
      this.currentRow &&
      this.currentRow.group &&
      row.key === this.currentRow.key
    ) {
      messageIndex = row.messages.mapBy("key").indexOf(this.currentMessage.key);
      messageIndex = Math.max(0, messageIndex);
    }
    return messageIndex;
  },

  updateSelectedRow() {
    const currentKey = this.get("currentRow.key");
    if (currentKey && this.rows) {
      const match = this.rows.find(m => m.key === currentKey);
      if (match) {
        const messageIndex = this.findEquivalentMessageIndex(match);
        this.selectRow(match, { messageIndex });
      } else {
        this.setProperties({
          currentRow: null,
          currentEnvPosition: 0,
          currentGroupedMessagesPosition: 0
        });
      }
    }
  },

  load(opts) {
    opts = opts || {};

    const data = {
      filter: this.filter.join("_")
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
    return ajax("/messages.json", {
      data: data
    })
      .then(data => {
        // guard against race: ensure the results we're trying to apply
        //                     match the current search terms
        if (compare(data.filter, this.filter) != 0) {
          return;
        }
        if (compare(data.search, this.search) != 0) {
          return;
        }

        if (data.messages.length > 0) {
          const newRows = this.toObjects(data.messages);
          const rows = this.rows;
          if (opts.before) {
            rows.unshiftObjects(newRows);
          } else {
            newRows.forEach(nrow => {
              rows.forEach(erow => {
                if (erow.key === nrow.key) {
                  rows.removeObject(erow);
                  if (this.currentRow === erow) {
                    // TODO would updateFromJson() work here?
                    const messageIndex = this.findEquivalentMessageIndex(nrow);
                    this.selectRow(nrow, { messageIndex });
                  }
                }
              });
            });
            rows.addObjects(newRows);
            if (newRows.length > 0) {
              increaseTitleCount(newRows.length);
            }
          }
        }
        this.set("total", data.total);
        return data;
      })
      .finally(() => this.set("loading", false));
  },

  reload() {
    this.set("total", 0);
    this.rows.clear();

    return this.load().then(data => this.updateCanLoadMore(data));
  },

  updateCanLoadMore(data) {
    if (!data) {
      return;
    }
    if (data.messages.length < BATCH_SIZE) {
      this.set("canLoadMore", false);
    } else {
      this.set("canLoadMore", true);
    }
  },

  loadMore() {
    const rows = this.rows;
    if (rows.length === 0) {
      this.load({});
      return;
    }

    const lastLog = rows[rows.length - 1];
    const lastKey = lastLog.group ? lastLog.row_id : lastLog.key;
    this.load({
      after: lastKey
    });
  },

  hideCountInLoadMore: computed("search", "filter", function() {
    const filter = this.filter;
    return (
      (this.search && this.search.length > 0) || (filter && filter.length < 6)
    );
  }),

  moreBefore: computed("rows.length", "canLoadMore", function() {
    return this.get("rows.length") >= BATCH_SIZE && this.canLoadMore;
  }),

  totalBefore: computed("total", "rows.length", function() {
    return this.total - this.rows.length;
  }),

  showMoreBefore: function() {
    const rows = this.rows;
    const firstLog = rows[0];
    const firstKey = firstLog.group ? firstLog.row_id : firstLog.key;
    const knownGroups = rows.filterBy("group").mapBy("regex");

    this.load({
      before: firstKey,
      knownGroups
    }).then(data => this.updateCanLoadMore(data));
  },

  regexSearch: computed("search", function() {
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
  }),

  toObjects(rows) {
    return rows.map(m => {
      if (m.group) {
        return Group.create(m);
      } else {
        return Message.create(m);
      }
    });
  }
});

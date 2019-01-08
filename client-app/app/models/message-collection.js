import { ajax, increaseTitleCount } from "client-app/lib/utilities";
import Message from "client-app/models/message";
import { compare } from "@ember/utils";
import { computed } from "@ember/object";

const BATCH_SIZE = 50;

export default Em.Object.extend({
  messages: Em.A(),
  currentMessage: null,
  total: 0,

  solve(message) {
    message.solve().then(() => {
      this.reload();
    });
  },

  destroy(message) {
    const messages = this.get("messages");
    const idx = messages.indexOf(message);
    message.destroy();
    message.set("selected", false);
    this.set("total", this.get("total") - 1);
    this.get("messages").removeObject(message);

    if (idx > 0) {
      message = messages[idx - 1];
      message.set("selected", true);
      this.set("currentMessage", message);
    } else {
      if (this.get("total") > 0) {
        message = messages[0];
        message.set("selected", true);
        this.set("currentMessage", message);
      } else {
        this.reload();
      }
    }
  },

  load(opts) {
    opts = opts || {};

    const data = {
      filter: this.get("filter").join("_")
    };

    const search = this.get("search");
    if (!_.isEmpty(search)) {
      data.search = search;
      const regexSearch = this.get("regexSearch");
      if (regexSearch) {
        data.regex_search = "true";
      }
    }

    if (opts.before) {
      data.before = opts.before;
    }

    if (opts.after) {
      data.after = opts.after;
    }

    return ajax("/messages.json", {
      data: data
    }).then(data => {
      // guard against race: ensure the results we're trying to apply
      //                     match the current search terms
      if (compare(data.filter, this.get("filter")) != 0) {
        return;
      }
      if (compare(data.search, this.get("search")) != 0) {
        return;
      }

      if (data.messages.length > 0) {
        const newRows = this.toMessages(data.messages);
        const messages = this.get("messages");
        if (opts.before) {
          messages.unshiftObjects(newRows);
        } else {
          newRows.forEach(nmsg => {
            messages.forEach(emsg => {
              if (emsg.key == nmsg.key) {
                messages.removeObject(emsg);
                if (this.get("currentMessage") === emsg) {
                  // TODO would updateFromJson() work here?
                  this.set("currentMessage", nmsg);
                  nmsg.set("selected", emsg.get("selected"));
                }
              }
            });
          });
          messages.addObjects(newRows);
          if (newRows.length > 0) {
            increaseTitleCount(newRows.length);
          }
        }
      }
      this.set("total", data.total);
      return data;
    });
  },

  reload() {
    this.set("total", 0);
    this.get("messages").clear();

    return this.load().then(data => {
      if (data.messages.length < BATCH_SIZE) {
        this.set("noMoreBefore", true);
      } else {
        this.set("noMoreBefore", false);
      }
    });
  },

  loadMore() {
    const messages = this.get("messages");
    if (messages.length === 0) {
      this.load({});
      return;
    }

    const lastKey = messages[messages.length - 1].get("key");
    this.load({
      after: lastKey
    });
  },

  moreBefore: computed("totalBefore", function() {
    return this.get("totalBefore") > 0;
  }),

  totalBefore: computed("total", "messages.length", function() {
    return this.get("total") - this.get("messages").length;
  }),

  showMoreBefore: function() {
    const messages = this.get("messages");
    const firstKey = messages[0].get("key");

    this.load({
      before: firstKey
    }).then(data => {
      if (data.messages.length < BATCH_SIZE) {
        this.set("noMoreBefore", true);
      } else {
        this.set("noMoreBefore", false);
      }
    });
  },

  regexSearch: computed("search", function() {
    const search = this.get("search");
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
  }),

  toMessages(messages) {
    return messages.map(m => Message.create(m));
  }
});

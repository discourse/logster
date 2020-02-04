import Component from "@ember/component";
import { not, equal } from "@ember/object/computed";
import { computed } from "@ember/object";
import Pattern from "client-app/models/pattern-item";
import { ajax } from "client-app/lib/utilities";

export default Component.extend({
  immutable: not("mutable"),
  showCounter: equal("key", "suppression"),

  init() {
    this._super(...arguments);
    if (this.get("patterns.length") < 1 && this.get("mutable")) {
      this.send("create");
    }
  },

  allPatterns: computed("patterns.[]", "newPatterns.[]", function() {
    const patterns = this.get("patterns");
    const newPatterns = this.get("newPatterns") || [];
    return [...newPatterns.reverse(), ...patterns.reverse()];
  }),

  makeAPICall(data = {}) {
    const { method } = data;
    delete data.method;

    return ajax(`/patterns/${this.get("key")}.json`, { method, data });
  },

  finallyBlock(pattern) {
    pattern.set("saving", false);
  },

  catchBlock(pattern, response) {
    if (response.responseText) {
      pattern.set("error", response.responseText);
    } else {
      pattern.set("error", "Unkown error occured. Please see dev console.");
    }
  },

  requestInit(pattern) {
    pattern.setProperties({
      saving: true,
      error: null
    });
  },

  actions: {
    create() {
      if (!this.get("newPatterns")) {
        this.set("newPatterns", []);
      }
      this.get("newPatterns").pushObject(Pattern.create({ isNew: true }));
    },

    trash(pattern) {
      if (pattern.get("isNew")) {
        this.get("newPatterns").removeObject(pattern);
        pattern.destroy();
      } else {
        this.requestInit(pattern);
        this.makeAPICall({
          method: "DELETE",
          pattern: pattern.get("value")
        })
          .then(() => {
            this.get("patterns").removeObject(pattern);
            pattern.destroy();
          })
          .catch(response => this.catchBlock(pattern, response))
          .finally(() => this.finallyBlock(pattern));
      }
    },

    save(pattern) {
      this.requestInit(pattern);
      let promise;
      if (pattern.get("isNew")) {
        promise = this.makeAPICall({
          method: "POST",
          pattern: pattern.valueBuffer,
          retroactive: !!pattern.retroactive
        }).then(response => {
          pattern.updateValue(response.pattern);
          pattern.set("isNew", false);
          this.get("patterns").pushObject(pattern);
          this.get("newPatterns").removeObject(pattern);
        });
      } else {
        promise = this.makeAPICall({
          method: "PUT",
          pattern: pattern.get("value"),
          new_pattern: pattern.get("valueBuffer")
        }).then(response => {
          pattern.updateValue(response.pattern);
          pattern.set("count", 0);
        });
      }
      promise
        .catch(response => {
          this.catchBlock(pattern, response);
        })
        .finally(() => this.finallyBlock(pattern));
    },

    resetCount(pattern) {
      pattern.set("saving", true);
      ajax("/reset-count.json", {
        method: "PUT",
        data: { pattern: pattern.get("value"), hard: !!pattern.get("hard") }
      })
        .then(() => {
          pattern.set("count", 0);
        })
        .catch(response => this.catchBlock(pattern, response))
        .finally(() => this.finallyBlock(pattern));
    },

    checkboxChanged(pattern) {
      pattern.toggleProperty("retroactive");
    }
  }
});

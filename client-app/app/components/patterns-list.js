import classic from "ember-classic-decorator";
import { equal, not } from "@ember/object/computed";
import Component from "@ember/component";
import { action, computed } from "@ember/object";
import Pattern from "client-app/models/pattern-item";
import { ajax } from "client-app/lib/utilities";

@classic
export default class PatternsList extends Component {
  @not("mutable") immutable;
  @equal("key", "suppression") showCounter;

  init() {
    super.init(...arguments);

    if (this.patterns.length < 1 && this.mutable) {
      this.create();
    }
  }

  @computed("patterns.[]", "newPatterns.[]")
  get allPatterns() {
    const patterns = this.patterns;
    const newPatterns = this.newPatterns || [];
    return [...newPatterns.reverse(), ...patterns.reverse()];
  }

  makeAPICall(data = {}) {
    const { method } = data;
    delete data.method;

    return ajax(`/patterns/${this.key}.json`, { method, data });
  }

  finallyBlock(pattern) {
    pattern.set("saving", false);
  }

  catchBlock(pattern, response) {
    if (response.responseText) {
      pattern.set("error", response.responseText);
    } else {
      pattern.set("error", "Unknown error occurred. Please see dev console.");
    }
  }

  requestInit(pattern) {
    pattern.setProperties({
      saving: true,
      error: null,
    });
  }

  @action
  create() {
    if (!this.newPatterns) {
      this.set("newPatterns", []);
    }
    this.newPatterns.pushObject(Pattern.create({ isNew: true }));
  }

  @action
  trash(pattern) {
    if (pattern.get("isNew")) {
      this.newPatterns.removeObject(pattern);
      pattern.destroy();
    } else {
      this.requestInit(pattern);
      this.makeAPICall({
        method: "DELETE",
        pattern: pattern.get("value"),
      })
        .then(() => {
          this.patterns.removeObject(pattern);
          pattern.destroy();
        })
        .catch((response) => this.catchBlock(pattern, response))
        .finally(() => this.finallyBlock(pattern));
    }
  }

  @action
  save(pattern) {
    this.requestInit(pattern);
    let promise;
    if (pattern.get("isNew")) {
      promise = this.makeAPICall({
        method: "POST",
        pattern: pattern.valueBuffer,
        retroactive: !!pattern.retroactive,
      }).then((response) => {
        pattern.updateValue(response.pattern);
        pattern.set("isNew", false);
        this.patterns.pushObject(pattern);
        this.newPatterns.removeObject(pattern);
      });
    } else {
      promise = this.makeAPICall({
        method: "PUT",
        pattern: pattern.get("value"),
        new_pattern: pattern.get("valueBuffer"),
      }).then((response) => {
        pattern.updateValue(response.pattern);
        pattern.set("count", 0);
      });
    }
    promise
      .catch((response) => {
        this.catchBlock(pattern, response);
      })
      .finally(() => this.finallyBlock(pattern));
  }

  @action
  resetCount(pattern) {
    pattern.set("saving", true);
    ajax("/reset-count.json", {
      method: "PUT",
      data: { pattern: pattern.get("value"), hard: !!pattern.get("hard") },
    })
      .then(() => {
        pattern.set("count", 0);
      })
      .catch((response) => this.catchBlock(pattern, response))
      .finally(() => this.finallyBlock(pattern));
  }

  @action
  checkboxChanged(pattern) {
    pattern.toggleProperty("retroactive");
  }
}

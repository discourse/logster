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
  async trash(pattern) {
    if (pattern.isNew) {
      this.newPatterns.removeObject(pattern);
      pattern.destroy();
      return;
    }

    this.requestInit(pattern);

    try {
      await this.makeAPICall({
        method: "DELETE",
        pattern: pattern.value,
      });

      this.patterns.removeObject(pattern);
      pattern.destroy();
    } catch (response) {
      this.catchBlock(pattern, response);
    } finally {
      this.finallyBlock(pattern);
    }
  }

  @action
  async save(pattern) {
    this.requestInit(pattern);

    try {
      if (pattern.isNew) {
        const response = await this.makeAPICall({
          method: "POST",
          pattern: pattern.valueBuffer,
          retroactive: !!pattern.retroactive,
        });

        pattern.updateValue(response.pattern);
        pattern.set("isNew", false);
        this.patterns.pushObject(pattern);
        this.newPatterns.removeObject(pattern);
      } else {
        const response = await this.makeAPICall({
          method: "PUT",
          pattern: pattern.value,
          new_pattern: pattern.valueBuffer,
        });

        pattern.updateValue(response.pattern);
        pattern.set("count", 0);
      }
    } catch (response) {
      this.catchBlock(pattern, response);
    } finally {
      this.finallyBlock(pattern);
    }
  }

  @action
  async resetCount(pattern) {
    pattern.set("saving", true);

    try {
      await ajax("/reset-count.json", {
        method: "PUT",
        data: { pattern: pattern.value, hard: !!pattern.hard },
      });

      pattern.set("count", 0);
    } catch (response) {
      this.catchBlock(pattern, response);
    } finally {
      this.finallyBlock(pattern);
    }
  }

  @action
  checkboxChanged(pattern) {
    pattern.toggleProperty("retroactive");
  }
}

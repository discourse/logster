import Component from "@glimmer/component";
import { and, fn, or } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import FaIcon from "@fortawesome/ember-fontawesome/components/fa-icon";
import Pattern from "client-app/models/pattern-item";
import { ajax } from "client-app/lib/utilities";

export default class PatternsList extends Component {
  @tracked createdPatterns = [];
  @tracked newPatterns;
  @tracked removedPatterns = [];

  constructor() {
    super(...arguments);
    this.newPatterns =
      this.args.mutable && this.args.patterns.length === 0
        ? [Pattern.create({ isNew: true })]
        : [];
  }

  get immutable() {
    return !this.args.mutable;
  }

  get showCounter() {
    return this.args.key === "suppression";
  }

  get allPatterns() {
    const persistedPatterns = [
      ...this.createdPatterns,
      ...this.args.patterns,
    ].filter((pattern) => !this.removedPatterns.includes(pattern));

    return [...this.newPatterns]
      .reverse()
      .concat(persistedPatterns.reverse());
  }

  request(url, settings) {
    return ajax(url, settings);
  }

  makeAPICall(data = {}) {
    const { method, ...requestData } = data;
    return this.request(`/patterns/${this.args.key}.json`, {
      method,
      data: requestData,
    });
  }

  requestInit(pattern) {
    pattern.setProperties({ saving: true, error: null });
  }

  catchBlock(pattern, response) {
    pattern.set(
      "error",
      response.responseText || "Unknown error occurred. Please see dev console."
    );
  }

  @action
  create() {
    this.newPatterns = [...this.newPatterns, Pattern.create({ isNew: true })];
  }

  @action
  updateValue(pattern, event) {
    pattern.set("valueBuffer", event.target.value);
  }

  @action
  async trash(pattern) {
    if (pattern.isNew) {
      this.newPatterns = this.newPatterns.filter((item) => item !== pattern);
      pattern.destroy();
      return;
    }

    this.requestInit(pattern);
    try {
      await this.makeAPICall({ method: "DELETE", pattern: pattern.value });
      this.createdPatterns = this.createdPatterns.filter(
        (item) => item !== pattern
      );
      this.removedPatterns = [...this.removedPatterns, pattern];
      pattern.destroy();
    } catch (response) {
      this.catchBlock(pattern, response);
    } finally {
      pattern.set("saving", false);
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
          retroactive: Boolean(pattern.retroactive),
        });
        pattern.updateValue(response.pattern);
        pattern.set("isNew", false);
        this.createdPatterns = [...this.createdPatterns, pattern];
        this.newPatterns = this.newPatterns.filter((item) => item !== pattern);
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
      pattern.set("saving", false);
    }
  }

  @action
  async resetCount(pattern) {
    pattern.set("saving", true);
    try {
      await this.request("/reset-count.json", {
        method: "PUT",
        data: { pattern: pattern.value, hard: Boolean(pattern.hard) },
      });
      pattern.set("count", 0);
    } catch (response) {
      this.catchBlock(pattern, response);
    } finally {
      pattern.set("saving", false);
    }
  }

  @action
  checkboxChanged(pattern, event) {
    pattern.set("retroactive", event.target.checked);
  }

  <template>
    {{#if @mutable}}
      <button class="btn new-pattern" type="button" {{on "click" this.create}}>
        <FaIcon @icon="plus" />
        <span>New</span>
      </button>
    {{/if}}

    {{#each this.allPatterns as |pattern|}}
      <div class="pattern-wrapper">
        <input
          type="text"
          value={{pattern.valueBuffer}}
          class="pattern-input"
          placeholder="Enter regular expression…"
          disabled={{or this.immutable pattern.saving}}
          {{on "input" (fn this.updateValue pattern)}}
        />

        {{#if @mutable}}
          {{#if pattern.hasBuffer}}
            <button
              disabled={{pattern.saving}}
              class="btn ok no-text save shrink"
              type="button"
              {{on "click" (fn this.save pattern)}}
            >
              <FaIcon @icon="check" />
            </button>
          {{/if}}

          <button
            disabled={{pattern.saving}}
            class="btn no-text trash shrink"
            type="button"
            {{on "click" (fn this.trash pattern)}}
          >
            <FaIcon @icon="trash-alt" />
          </button>
        {{/if}}

        {{#if this.showCounter}}
          <input
            disabled
            title="Number of logs that have been suppressed by this pattern"
            class="count shrink"
            value={{pattern.count}}
          />
          <button
            class="btn no-text reset shrink"
            title="Reset count of suppressed logs"
            disabled={{pattern.zeroCount}}
            type="button"
            {{on "click" (fn this.resetCount pattern)}}
          >
            <FaIcon @icon="redo-alt" />
          </button>
        {{/if}}
      </div>

      {{#if (and @applyRetroactivelyCheckbox pattern.isNew)}}
        <div class="retro-checkbox">
          <input
            checked={{pattern.retroactive}}
            type="checkbox"
            class="checkbox"
            {{on "change" (fn this.checkboxChanged pattern)}}
          />
          Apply retroactively
        </div>
      {{/if}}

      {{~#if pattern.error~}}
        <pre class="api-error">{{pattern.error}}</pre>
      {{~/if~}}
    {{/each}}
  </template>
}

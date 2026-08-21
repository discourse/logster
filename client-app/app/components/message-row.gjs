import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { modifier } from "ember-modifier";
import FaIcon from "@fortawesome/ember-fontawesome/components/fa-icon";
import TimeFormatter from "client-app/components/time-formatter";

const finishInsertion = modifier((_element, [component]) => {
  const topPanel = document.getElementById("top-panel");
  if (topPanel && component.stickToBottom) {
    topPanel.scrollTop =
      topPanel.scrollHeight - parseFloat(getComputedStyle(topPanel).height);
  }
});

export default class MessageRow extends Component {
  stickToBottom = false;

  constructor() {
    super(...arguments);
    const topPanel = document.getElementById("top-panel");
    if (topPanel) {
      const height = parseFloat(getComputedStyle(topPanel).height);
      this.stickToBottom =
        topPanel.scrollHeight - 20 < height + topPanel.scrollTop;
    }
  }

  <template>
    <div
      class="message-row {{@model.rowClass}} {{if @model.selected 'selected'}}"
      role="button"
      {{on "click" @selectRow}}
      {{finishInsertion this}}
      ...attributes
    >
      <div class="count">
        {{#if @model.showCount}}{{@model.count}}{{/if}}
      </div>

      <div class="severity">
        {{#if @model.glyph}}
          <FaIcon
            @icon={{@model.glyph}}
            @prefix={{@model.prefix}}
            class={{@model.klass}}
          />
        {{/if}}
      </div>

      <div class="message-body">{{@model.displayMessage}}</div>

      <div class="protected">
        {{#if @model.protected}}
          <FaIcon
            @icon="lock"
            aria-label="message is protected, clearing will not remove it"
          />
        {{/if}}
      </div>

      <div class="time">
        <TimeFormatter @timestamp={{@model.timestamp}} />
      </div>
    </div>
  </template>
}

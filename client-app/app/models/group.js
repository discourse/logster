import Message from "client-app/models/message";
import { default as EmberObject, computed } from "@ember/object";
import { reads } from "@ember/object/computed";
import { ajax } from "client-app/lib/utilities";

export default EmberObject.extend({
  selected: false,
  showCount: true,
  key: reads("regex"),
  displayMessage: reads("messages.firstObject.message"),

  init() {
    this._super(...arguments);
    const messages = this.messages.map(m => Message.create(m));
    this.set("messages", messages);
  },

  glyph: computed(function() {
    return "clone";
  }),

  prefix: computed(function() {
    return "far";
  }),

  solveAll() {
    return ajax("/solve-group", { type: "POST", data: { regex: this.regex } });
  }
});

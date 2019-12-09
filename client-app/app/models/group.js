import Message from "client-app/models/message";
import { default as EmberObject, computed } from "@ember/object";
import { alias } from "@ember/object/computed";

export default EmberObject.extend({
  selected: false,
  showCount: true,
  key: alias("regex"),

  init() {
    this._super(...arguments);
    const messages = this.messages.map(m => Message.create(m));
    this.set("messages", messages);
  },

  displayMessage: computed("regex", function() {
    return this.regex;
  }),

  glyph: computed(function() {
    return "<i class='fa fa-clone group'></i>";
  })
});

import Message from "client-app/models/message";
import { default as EmberObject, computed } from "@ember/object";
import { reads } from "@ember/object/computed";

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
    return "<i class='fa fa-clone group'></i>";
  })
});

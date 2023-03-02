import classic from "ember-classic-decorator";
import { reads } from "@ember/object/computed";
import Message from "client-app/models/message";
import { default as EmberObject, computed } from "@ember/object";
import { ajax } from "client-app/lib/utilities";

@classic
export default class Group extends EmberObject {
  selected = false;
  showCount = true;

  @reads("regex") key;
  @reads("messages.firstObject.message") displayMessage;

  init() {
    super.init(...arguments);
    const messages = this.messages.map((m) => Message.create(m));
    this.set("messages", messages);
  }

  @computed
  get glyph() {
    return "clone";
  }

  @computed
  get prefix() {
    return "far";
  }

  solveAll() {
    return ajax("/solve-group", { type: "POST", data: { regex: this.regex } });
  }
}

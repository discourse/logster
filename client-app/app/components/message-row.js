import Component from "@ember/component";

let CHECKED_BOTTOM;
let STICK_TO_BOTTOM;

export default Component.extend({
  tagName: "tr",

  classNameBindings: [
    "model.rowClass",
    ":message-row",
    "model.selected:selected"
  ],

  click() {
    this.selectedMessage(this.get("model"));
  },

  willInsertElement() {
    if (CHECKED_BOTTOM) {
      return;
    }

    const $topPanel = Em.$("#top-panel");

    const scrollTop = $topPanel.scrollTop();
    const height = $topPanel.height();
    const scrollHeight = $topPanel[0].scrollHeight;

    STICK_TO_BOTTOM = scrollHeight - 20 < height + scrollTop;
    CHECKED_BOTTOM = true;
  },

  didInsertElement() {
    const $topPanel = Em.$("#top-panel");
    Em.run.next(() => {
      CHECKED_BOTTOM = false;

      if (STICK_TO_BOTTOM) {
        STICK_TO_BOTTOM = false;
        $topPanel.scrollTop($topPanel[0].scrollHeight - $topPanel.height());
      }
    });
  }
});

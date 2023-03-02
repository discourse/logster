import classic from "ember-classic-decorator";
import { classNameBindings, tagName } from "@ember-decorators/component";
import Component from "@ember/component";

let CHECKED_BOTTOM;
let STICK_TO_BOTTOM;

@classic
@tagName("div")
@classNameBindings("model.rowClass", ":message-row", "model.selected:selected")
export default class MessageRow extends Component {
  willInsertElement() {
    super.willInsertElement(...arguments);
    if (CHECKED_BOTTOM) {
      return;
    }

    const topPanel = document.getElementById("top-panel");
    if (!topPanel) return;

    const height = parseFloat(getComputedStyle(topPanel).height);
    STICK_TO_BOTTOM = topPanel.scrollHeight - 20 < height + topPanel.scrollTop;
    CHECKED_BOTTOM = true;
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    const topPanel = document.getElementById("top-panel");
    if (!topPanel) return;

    CHECKED_BOTTOM = false;
    if (STICK_TO_BOTTOM) {
      STICK_TO_BOTTOM = false;
      topPanel.scrollTop =
        topPanel.scrollHeight - parseFloat(getComputedStyle(topPanel).height);
    }
  }

  click() {
    this.selectRow();
  }
}

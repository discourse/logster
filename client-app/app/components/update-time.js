import classic from "ember-classic-decorator";
import Component from "@ember/component";
import { formatTime } from "client-app/lib/utilities";
import { later } from "@ember/runloop";

@classic
export default class UpdateTime extends Component {
  didInsertElement() {
    super.didInsertElement(...arguments);
    later(this, this.updateTimes, 60000);
  }

  updateTimes() {
    Array.from(document.querySelectorAll(".auto-update-time")).forEach(
      (node) => {
        const timestamp = parseInt(node.dataset.timestamp);
        if (!timestamp) return;
        const formatted = formatTime(timestamp);
        if (formatted !== node.innerText) {
          node.innerText = formatted;
        }
      }
    );
    later(this, this.updateTimes, 60000);
  }
}

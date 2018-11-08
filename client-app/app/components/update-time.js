import Component from "@ember/component";
import { formatTime } from "client-app/lib/utilities";

export default Component.extend({
  didInsertElement() {
    const updateTimes = () => {
      Em.$(".auto-update-time").each(function() {
        const timestamp = parseInt(this.getAttribute("data-timestamp"), 10);
        const elem = this;
        const text = formatTime(timestamp);

        if (text !== elem.innerText) {
          elem.innerText = text;
        }
      });
      Em.run.later(updateTimes, 60000);
    };

    Em.run.later(updateTimes, 60000);
  }
});

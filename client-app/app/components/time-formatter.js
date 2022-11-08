import Component from "@ember/component";
import { formatTime } from "client-app/lib/utilities";
import { computed } from "@ember/object";

export default Component.extend({
  tagName: "span",
  classNames: "auto-update-time",
  attributeBindings: ["dataTimestamp:data-timestamp", "title"],

  title: computed("moment", function () {
    return this.moment.format();
  }),

  dataTimestamp: computed.reads("timestamp"),

  moment: computed("timestamp", function () {
    return moment(this.timestamp);
  }),

  time: computed("timestamp", function () {
    return formatTime(this.timestamp);
  }),
});

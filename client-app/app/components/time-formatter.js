import Component from "@ember/component";
import { formatTime } from "client-app/lib/utilities";
import { computed } from "@ember/object";

export default Component.extend({
  tagName: "span",
  classNames: "auto-update-time",
  attributeBindings: ["dataTimestamp:data-timestamp", "title"],

  title: computed(function() {
    return this.get("moment").format();
  }),

  dataTimestamp: computed(function() {
    return this.get("timestamp");
  }),

  moment: computed(function() {
    return moment(this.get("timestamp"));
  }),

  time: computed("timestamp", function() {
    return formatTime(this.get("timestamp"));
  })
});

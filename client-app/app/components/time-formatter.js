import Component from "@ember/component";
import { formatTime } from "client-app/lib/utilities";

export default Component.extend({
  tagName: "span",
  classNames: "auto-update-time",
  attributeBindings: ["dataTimestamp:data-timestamp", "title"],

  title: function() {
    return this.get("moment").format();
  }.property(),

  dataTimestamp: function() {
    return this.get("timestamp");
  }.property(),

  moment: function() {
    return moment(this.get("timestamp"));
  }.property(),

  time: function() {
    return formatTime(this.get("timestamp"));
  }.property("timestamp")
});

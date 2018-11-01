import { ajax, buildHashString } from "client-app/lib/utilities";
import Preload from "client-app/lib/preload";

export default Em.Object.extend({
  MAX_LEN: 200,

  expand() {
    this.set("expanded", true);
  },

  solve() {
    return ajax("/solve/" + this.get("key"), { type: "PUT" });
  },

  destroy() {
    return ajax("/message/" + this.get("key"), { type: "DELETE" });
  },

  protect() {
    this.set("protected", true);
    return ajax("/protect/" + this.get("key"), { type: "PUT" });
  },
  unprotect() {
    this.set("protected", false);
    return ajax("/unprotect/" + this.get("key"), { type: "DELETE" });
  },

  showCount: function() {
    return this.get("count") > 1;
  }.property("count"),

  hasMore: function() {
    const message = this.get("message");
    const expanded = this.get("expanded");

    return !expanded && message.length > this.MAX_LEN;
  }.property("message", "expanded"),

  shareUrl: function() {
    return Preload.get("rootPath") + "/show/" + this.get("key");
  }.property("key"),

  displayMessage: function() {
    let message = this.get("message");
    const expanded = this.get("expanded");

    if (!expanded && message.length > this.MAX_LEN) {
      message = message.substr(0, this.MAX_LEN);
    }
    return message;
  }.property("message", "expanded"),

  updateFromObject(other) {
    // XXX Only updatable property is count right now
    this.set("count", other.get("count"));
  },

  canSolve: function() {
    const backtrace = this.get("backtrace");
    return (
      this.get("env.application_version") && backtrace && backtrace.length > 0
    );
  }.property(),

  envTable: function() {
    return buildHashString(this.get("env"));
  }.property("env"),

  rowClass: function() {
    switch (this.get("severity")) {
      case 0:
        return "debug";
      case 1:
        return "info";
      case 2:
        return "warn";
      case 3:
        return "error";
      case 4:
        return "fatal";
    }
  }.property("severity"),

  glyph: function() {
    switch (this.get("severity")) {
      case 0:
        return "";
      case 1:
        return "";
      case 2:
        return "<i class='fa fa-exclamation-circle warning'></i>";
      case 3:
        return "<i class='fa fa-times-circle error'></i>";
      case 4:
        return "<i class='fa fa-times-circle fatal'></i>";
    }
  }.property("severity")
});

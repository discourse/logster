import { ajax } from "client-app/lib/utilities";
import Preload from "client-app/lib/preload";
import { computed } from "@ember/object";

export default Em.Object.extend({
  MAX_LEN: 200,

  fetchEnv() {
    return ajax(`/fetch-env/${this.key}.json`).then(env =>
      this.set("env", env)
    );
  },

  expand() {
    this.set("expanded", true);
  },

  solve() {
    return ajax(`/solve/${this.key}`, { type: "PUT" });
  },

  destroy() {
    return ajax(`/message/${this.key}`, { type: "DELETE" });
  },

  protect() {
    this.set("protected", true);
    return ajax(`/protect/${this.key}`, { type: "PUT" });
  },

  unprotect() {
    this.set("protected", false);
    return ajax(`/unprotect/${this.key}`, { type: "DELETE" });
  },

  showCount: computed("count", function() {
    return this.count > 1;
  }),

  hasMore: computed("message", "expanded", function() {
    return !this.expanded && this.message.length > this.MAX_LEN;
  }),

  shareUrl: computed("key", function() {
    return `${Preload.get("rootPath")}/show/${this.key}`;
  }),

  displayMessage: computed("message", "expanded", function() {
    let message = this.message;

    if (!this.expanded && this.message.length > this.MAX_LEN) {
      message = this.message.substr(0, this.MAX_LEN);
    }
    return message;
  }),

  updateFromObject(other) {
    // XXX Only updatable property is count right now
    this.set("count", other.get("count"));
  },

  canSolve: computed("env.{application_version,length}", function() {
    const appVersion = Array.isArray(this.env)
      ? this.env
          .map(e => e.application_version)
          .compact()
          .join("")
      : this.env && this.env.application_version;
    return appVersion && this.backtrace && this.backtrace.length > 0;
  }),

  rowClass: computed("severity", function() {
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
  }),

  glyph: computed("severity", function() {
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
  })
});

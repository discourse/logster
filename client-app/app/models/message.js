import classic from "ember-classic-decorator";
import { gt } from "@ember/object/computed";
import EmberObject from "@ember/object";
import { ajax } from "client-app/lib/utilities";
import { getRootPath } from "client-app/lib/preload";
import { computed } from "@ember/object";

@classic
export default class Message extends EmberObject {
  MAX_LEN = 200;

  @gt("count", 1) showCount;

  @computed("MAX_LEN", "expanded", "message.length")
  get hasMore() {
    return !this.expanded && this.message.length > this.MAX_LEN;
  }

  @computed("key")
  get shareUrl() {
    return `${getRootPath()}/show/${this.key}`;
  }

  @computed("MAX_LEN", "expanded", "message.length")
  get displayMessage() {
    let message = this.message;

    if (!this.expanded && this.message.length > this.MAX_LEN) {
      message = this.message.substr(0, this.MAX_LEN);
    }
    return message;
  }

  @computed("backtrace.length", "env.{application_version,length}")
  get canSolve() {
    const appVersion = Array.isArray(this.env)
      ? this.env
          .map((e) => e.application_version)
          .compact()
          .join("")
      : this.env && this.env.application_version;
    return appVersion && this.backtrace && this.backtrace.length > 0;
  }

  @computed("severity")
  get rowClass() {
    switch (this.severity) {
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
      default:
        return "unknown";
    }
  }

  @computed("severity")
  get glyph() {
    switch (this.severity) {
      case 0:
        return "";
      case 1:
        return "";
      case 2:
        return "exclamation-circle";
      case 3:
        return "times-circle";
      case 4:
        return "times-circle";
      default:
        return "question-circle";
    }
  }

  get prefix() {
    return "fas";
  }

  @computed("severity")
  get klass() {
    switch (this.severity) {
      case 0:
        return "";
      case 1:
        return "";
      case 2:
        return "warning";
      case 3:
        return "error";
      case 4:
        return "fatal";
      default:
        return "unknown";
    }
  }

  fetchEnv() {
    return ajax(`/fetch-env/${this.key}.json`).then((env) =>
      this.set("env", env)
    );
  }

  expand() {
    this.set("expanded", true);
  }

  solve() {
    return ajax(`/solve/${this.key}`, { type: "PUT" });
  }

  destroy() {
    return ajax(`/message/${this.key}`, { type: "DELETE" });
  }

  protect() {
    this.set("protected", true);
    return ajax(`/protect/${this.key}`, { type: "PUT" });
  }

  unprotect() {
    this.set("protected", false);
    return ajax(`/unprotect/${this.key}`, { type: "DELETE" });
  }

  updateFromObject(other) {
    // XXX Only updatable property is count right now
    this.set("count", other.get("count"));
  }
}

import classic from "ember-classic-decorator";
import { tagName } from "@ember-decorators/component";
import { computed } from "@ember/object";
import Component from "@ember/component";
import { formatTime } from "client-app/lib/utilities";
import { later } from "@ember/runloop";

const UPDATE_INTERVAL = 60_000;

@classic
@tagName("")
export default class TimeFormatter extends Component {
  didInsertElement() {
    super.didInsertElement(...arguments);
    later(this, this.updateTime, UPDATE_INTERVAL);
  }

  @computed("timestamp")
  get title() {
    return moment(this.timestamp).format();
  }

  @computed("timestamp")
  get time() {
    return formatTime(this.timestamp);
  }

  updateTime() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.notifyPropertyChange("timestamp");
    later(this, this.updateTime, UPDATE_INTERVAL);
  }
}

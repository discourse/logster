import classic from "ember-classic-decorator";
import {
  attributeBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import { computed } from "@ember/object";
import { reads } from "@ember/object/computed";
import Component from "@ember/component";
import { formatTime } from "client-app/lib/utilities";

@classic
@tagName("span")
@classNames("auto-update-time")
@attributeBindings("dataTimestamp:data-timestamp", "title")
export default class TimeFormatter extends Component {
  @reads("timestamp") dataTimestamp;

  @computed("moment")
  get title() {
    return this.moment.format();
  }

  @computed("timestamp")
  get moment() {
    return moment(this.timestamp);
  }

  @computed("timestamp")
  get time() {
    return formatTime(this.timestamp);
  }
}

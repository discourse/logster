import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import { tracked } from "@glimmer/tracking";
import moment from "moment";
import { formatTime } from "client-app/lib/utilities";

const UPDATE_INTERVAL = 60_000;

export default class TimeFormatter extends Component {
  @tracked tick = 0;

  constructor() {
    super(...arguments);
    const interval = setInterval(() => this.tick++, UPDATE_INTERVAL);
    registerDestructor(this, () => clearInterval(interval));
  }

  get title() {
    return moment(this.args.timestamp).format();
  }

  get time() {
    this.tick;
    return formatTime(this.args.timestamp);
  }

  <template>
    <span title={{this.title}} ...attributes>{{this.time}}</span>
  </template>
}

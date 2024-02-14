import Component from "@ember/component";
import { computed } from "@ember/object";

export default class BackToSiteLink extends Component {
  @computed("attrs.text", "attrs.path")
  get shouldDisplay() {
    return this.text && this.path;
  }
}

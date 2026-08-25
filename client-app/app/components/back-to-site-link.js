import Component from "@glimmer/component";

export default class BackToSiteLink extends Component {
  get shouldDisplay() {
    return this.args.text && this.args.path;
  }
}

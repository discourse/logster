import Component from "@glimmer/component";
import FaIcon from "@fortawesome/ember-fontawesome/components/fa-icon";

export default class BackToSiteLink extends Component {
  get shouldDisplay() {
    return this.args.text && this.args.path;
  }

  <template>
    {{#if this.shouldDisplay}}
      <div id="back-to-site-panel">
        <a href={{@path}} rel="noopener noreferrer">
          <FaIcon @icon="arrow-left" />
          {{@text}}
        </a>
      </div>
    {{/if}}
  </template>
}

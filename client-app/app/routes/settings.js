import Route from "@ember/routing/route";
import { ajax } from "client-app/lib/utilities";

export default Route.extend({
  model() {
    return ajax("/settings.json");
  },

  setupController(controller, model) {
    this._super(...arguments);
    const showCodedPatterns =
      model.coded_patterns && model.coded_patterns.length > 0;
    controller.set("showCodedPatterns", showCodedPatterns);
  }
});

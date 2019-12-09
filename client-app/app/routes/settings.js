import Route from "@ember/routing/route";
import { ajax } from "client-app/lib/utilities";
import Pattern from "client-app/models/pattern-item";

export default Route.extend({
  model() {
    return ajax("/settings.json");
  },

  setupController(controller, model) {
    this._super(...arguments);
    const suppression = model.suppression;
    const codedSuppression = suppression
      .filter(p => p.hard)
      .map(hash => Pattern.create(hash));

    const customSuppression = suppression
      .reject(p => p.hard)
      .map(hash => Pattern.create(hash));

    const grouping = model.grouping.map(hash => Pattern.create(hash));
    const showCodedSuppression = codedSuppression.length > 0;
    controller.setProperties({
      showCodedSuppression,
      codedSuppression,
      customSuppression,
      grouping
    });
  }
});

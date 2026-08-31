import { trackedArray } from "@ember/reactive/collections";
import Route from "@ember/routing/route";
import { ajax } from "client-app/lib/utilities";
import Pattern from "client-app/models/pattern-item";

export default class SettingsRoute extends Route {
  model() {
    return ajax("/settings.json");
  }

  setupController(controller, model) {
    super.setupController(...arguments);
    const suppression = model.suppression;
    const codedSuppression = trackedArray(
      suppression.filter((p) => p.hard).map((hash) => Pattern.create(hash))
    );

    const customSuppression = trackedArray(
      suppression.filter((p) => !p.hard).map((hash) => Pattern.create(hash))
    );

    const grouping = trackedArray(
      model.grouping.map((hash) => Pattern.create(hash))
    );
    const showCodedSuppression = codedSuppression.length > 0;
    controller.setProperties({
      showCodedSuppression,
      codedSuppression,
      customSuppression,
      grouping,
    });
  }
}

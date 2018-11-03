import Route from "@ember/routing/route";
import Message from "client-app/models/message";
import { preloadOrAjax } from "client-app/lib/utilities";

export default Route.extend({
  model(params) {
    return preloadOrAjax("/show/" + params.id + ".json");
  },

  setupController(controller, model) {
    this._super(...arguments);
    controller.set("model", Message.create(model));
  }
});

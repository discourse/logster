import classic from "ember-classic-decorator";
import Route from "@ember/routing/route";
import Message from "client-app/models/message";
import { preloadOrAjax } from "client-app/lib/utilities";

@classic
export default class ShowRoute extends Route {
  model(params) {
    return preloadOrAjax("/show/" + params.id + ".json");
  }

  setupController(controller, model) {
    super.setupController(...arguments);
    controller.set("model", Message.create(model));
  }
}

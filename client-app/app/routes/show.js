import Route from "@ember/routing/route";
import Message from "client-app/models/message";
import { preloadOrAjax } from "client-app/lib/utilities";

export default class ShowRoute extends Route {
  async model(params) {
    return Message.create(await preloadOrAjax("/show/" + params.id + ".json"));
  }
}

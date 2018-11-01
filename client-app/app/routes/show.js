import Route from "@ember/routing/route";
import Message from "client-app/models/message";
import { preloadOrAjax } from "client-app/lib/utilities";

export default Route.extend({
  model(params) {
    return new Promise((resolve, reject) => {
      preloadOrAjax("/show/" + params.id + ".json")
        .then(json => {
          resolve(Message.create(json));
        })
        .catch(reject);
    });
  }
});

import Route from "@ember/routing/route";
import MessageCollection from "client-app/models/message-collection";
import { isHidden } from "client-app/lib/utilities";

export default Route.extend({
  model() {
    // TODO from preload json?
    return MessageCollection.create();
  },

  setupController(controller, model) {
    this._super(controller, model);
    model.reload();

    let times = 0;
    let backoff = 1;

    this.refreshInterval = setInterval(() => {
      if (model.loading) {
        return;
      }
      times += 1;
      const hidden = isHidden();
      let load = !hidden;

      if (hidden) {
        if (times % backoff === 0) {
          load = true;
          if (backoff < 20) {
            backoff++;
          }
        }
      }
      // refresh a lot less aggressively in background
      if (load) {
        model.loadMore();
        if (!hidden) {
          backoff = 1;
        }
      }
    }, 3000);

    this.events.on("panelResized", amount => {
      controller.resizePanels(amount);
    });
  },

  deactivate() {
    clearInterval(this.refreshInterval);
  }
});

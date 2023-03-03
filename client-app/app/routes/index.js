import classic from "ember-classic-decorator";
import { inject as service } from "@ember/service";
import Route from "@ember/routing/route";
import MessageCollection, {
  SEVERITIES,
} from "client-app/models/message-collection";
import { isHidden } from "client-app/lib/utilities";

@classic
export default class IndexRoute extends Route {
  @service events;

  model() {
    // TODO from preload json?
    return MessageCollection.create();
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    for (const severity of SEVERITIES) {
      model.set(`show${severity}`, controller[`show${severity}`]);
    }

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

    this.events.on("panelResized", (amount) => {
      controller.resizePanels(amount);
    });
  }

  deactivate() {
    clearInterval(this.refreshInterval);
  }
}

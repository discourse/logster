import classic from "ember-classic-decorator";
import { classNames } from "@ember-decorators/component";
import { inject as service } from "@ember/service";
import Component from "@ember/component";
import { scheduleOnce, throttle } from "@ember/runloop";
import { bound } from "client-app/lib/decorators";

const MOVE_EVENTS = ["touchmove", "mousemove"];
const UP_EVENTS = ["touchend", "mouseup"];
const DOWN_EVENTS = ["touchstart", "mousedown"];

@classic
@classNames("divider")
export default class PanelResizer extends Component {
  @service events;

  resizing = false;

  didInsertElement() {
    super.didInsertElement(...arguments);
    // inspired by http://plugins.jquery.com/misc/textarea.js
    this.set("divider", document.querySelector(".divider"));
    for (const name of DOWN_EVENTS) {
      this.divider.addEventListener(name, this.dividerClickHandler);
    }
    scheduleOnce("afterRender", this, "initialDivideView");
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    for (const name of DOWN_EVENTS) {
      this.divider.removeEventListener(name, this.dividerClickHandler);
    }
  }

  initialDivideView() {
    const amount = (localStorage && localStorage.logster_divider_bottom) || 300;
    const fromTop = window.innerHeight - parseInt(amount, 10);
    this.divideView(fromTop);
  }

  divideView(fromTop) {
    const height = window.innerHeight;
    const fromBottom = height - fromTop;

    if (fromTop < 100 || fromTop + 170 > height) {
      return;
    }

    this.divider.style.bottom = `${fromBottom - 5}px`;
    this.events.trigger("panelResized", fromBottom);
  }

  @bound
  performDrag(e) {
    throttle(this, this.throttledPerformDrag, e, 25);
  }

  throttledPerformDrag(e) {
    if (this.resizing) {
      this.divideView(
        e.clientY || (e.touches && e.touches[0] && e.touches[0].clientY)
      );
    }
  }

  @bound
  endDrag /* e */() {
    const overlay = document.getElementById("overlay");
    if (overlay) {
      overlay.parentElement.removeChild(overlay);
    }

    this.set("resizing", false);

    if (localStorage) {
      localStorage.logster_divider_bottom = parseInt(
        this.divider.style.bottom,
        10
      );
    }

    for (const name of MOVE_EVENTS) {
      document.removeEventListener(name, this.performDrag);
    }
    for (const name of UP_EVENTS) {
      document.removeEventListener(name, this.endDrag);
    }
  }

  @bound
  dividerClickHandler(e) {
    e.preventDefault(); // for disabling pull-down-to-refresh on mobile

    const overlay = document.createElement("DIV");
    overlay.id = "overlay";
    document.body.appendChild(overlay);

    this.set("resizing", true);

    for (const name of MOVE_EVENTS) {
      document.addEventListener(name, this.performDrag);
    }
    for (const name of UP_EVENTS) {
      document.addEventListener(name, this.endDrag);
    }
  }
}

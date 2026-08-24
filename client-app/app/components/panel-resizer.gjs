import Component from "@glimmer/component";
import { action } from "@ember/object";
import { scheduleOnce, throttle } from "@ember/runloop";
import { modifier } from "ember-modifier";
import {
  getLocalStorage,
  setLocalStorage,
} from "client-app/lib/utilities";

const MOVE_EVENTS = ["touchmove", "mousemove"];
const UP_EVENTS = ["touchend", "mouseup"];
const DOWN_EVENTS = ["touchstart", "mousedown"];

const setupResizer = modifier((element, [component]) => {
  component.setup(element);
  return () => component.teardown();
});

export default class PanelResizer extends Component {
  divider = null;
  resizing = false;

  setup(element) {
    this.divider = element;
    for (const name of DOWN_EVENTS) {
      element.addEventListener(name, this.dividerClickHandler);
    }
    scheduleOnce("afterRender", this, this.initialDivideView);
  }

  teardown() {
    if (this.divider) {
      for (const name of DOWN_EVENTS) {
        this.divider.removeEventListener(name, this.dividerClickHandler);
      }
    }
    this.removeDocumentListeners();
    document.getElementById("overlay")?.remove();
    this.divider = null;
  }

  initialDivideView() {
    const amount = getLocalStorage("logster_divider_bottom", 300, false);
    this.divideView(window.innerHeight - parseInt(amount, 10));
  }

  divideView(fromTop) {
    const height = window.innerHeight;
    const fromBottom = height - fromTop;

    if (fromTop < 100 || fromTop + 170 > height) {
      return;
    }

    this.divider.style.bottom = `${fromBottom - 5}px`;
    this.args.onResize(fromBottom);
  }

  @action
  performDrag(event) {
    throttle(this, this.throttledPerformDrag, event, 25);
  }

  throttledPerformDrag(event) {
    if (this.resizing) {
      this.divideView(event.clientY || event.touches?.[0]?.clientY);
    }
  }

  removeDocumentListeners() {
    for (const name of MOVE_EVENTS) {
      document.removeEventListener(name, this.performDrag);
    }
    for (const name of UP_EVENTS) {
      document.removeEventListener(name, this.endDrag);
    }
  }

  @action
  endDrag() {
    document.getElementById("overlay")?.remove();
    this.resizing = false;

    if (this.divider?.style.bottom) {
      setLocalStorage(
        "logster_divider_bottom",
        parseInt(this.divider.style.bottom, 10),
        false
      );
    }

    this.removeDocumentListeners();
  }

  @action
  dividerClickHandler(event) {
    event.preventDefault();

    const overlay = document.createElement("div");
    overlay.id = "overlay";
    document.body.appendChild(overlay);
    this.resizing = true;

    for (const name of MOVE_EVENTS) {
      document.addEventListener(name, this.performDrag);
    }
    for (const name of UP_EVENTS) {
      document.addEventListener(name, this.endDrag);
    }
  }

  <template>
    <div class="divider" {{setupResizer this}} ...attributes>
      <div class="line-1"></div>
      <div class="line-2"></div>
      <div class="line-3"></div>
    </div>
  </template>
}

import Component from "@ember/component";
import { scheduleOnce, throttle } from "@ember/runloop";

const MOVE_EVENTS = ["touchmove", "mousemove"];
const UP_EVENTS = ["touchend", "mouseup"];
const DOWN_EVENTS = ["touchstart", "mousedown"];

export default Component.extend({
  resizing: false,
  classNames: ["divider"],

  divideView(fromTop) {
    const height = window.innerHeight;
    const fromBottom = height - fromTop;

    if (fromTop < 100 || fromTop + 170 > height) {
      return;
    }

    this.divider.style.bottom = `${fromBottom - 5}px`;
    this.events.trigger("panelResized", fromBottom);
  },

  performDrag() {
    if (this._performDrag) return this._performDrag;

    const handler = e => {
      if (this.resizing) {
        this.divideView(
          e.clientY || (e.touches && e.touches[0] && e.touches[0].clientY)
        );
      }
    };

    const throttled = e => {
      throttle(this, handler, e, 25);
    };

    this.set("_performDrag", throttled);
    return this._performDrag;
  },

  endDrag() {
    if (this._endDrag) return this._endDrag;

    const handler = () => {
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

      MOVE_EVENTS.forEach(name =>
        document.removeEventListener(name, this.performDrag())
      );
      UP_EVENTS.forEach(name =>
        document.removeEventListener(name, this.endDrag())
      );
    };
    this.set("_endDrag", handler);
    return this._endDrag;
  },

  dividerClickHandler() {
    if (this._dividerClickHandler) return this._dividerClickHandler;

    const handler = e => {
      e.preventDefault(); // for disabling pull-down-to-refresh on mobile
      const overlay = document.createElement("DIV");
      overlay.id = "overlay";
      document.body.appendChild(overlay);
      this.set("resizing", true);
      MOVE_EVENTS.forEach(name =>
        document.addEventListener(name, this.performDrag())
      );
      UP_EVENTS.forEach(name =>
        document.addEventListener(name, this.endDrag())
      );
    };
    this.set("_dividerClickHandler", handler);
    return this._dividerClickHandler;
  },

  didInsertElement() {
    // inspired by http://plugins.jquery.com/misc/textarea.js
    this.set("divider", document.querySelector(".divider"));
    DOWN_EVENTS.forEach(name => {
      this.divider.addEventListener(name, this.dividerClickHandler());
    });
    scheduleOnce("afterRender", this, "initialDivideView");
  },

  initialDivideView() {
    const amount = (localStorage && localStorage.logster_divider_bottom) || 300;
    const fromTop = window.innerHeight - parseInt(amount, 10);
    this.divideView(fromTop);
  },

  willDestroyElement() {
    DOWN_EVENTS.forEach(name =>
      this.divider.removeEventListener(name, this.dividerClickHandler())
    );
  }
});

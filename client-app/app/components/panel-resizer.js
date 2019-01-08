import Component from "@ember/component";
const MOVE_EVENTS = ["touchmove", "mousemove"];
const UP_EVENTS = ["touchend", "mouseup"];
const DOWN_EVENTS = ["touchstart", "mousedown"];

export default Component.extend({
  classNames: ["divider"],

  divideView(fromTop, win) {
    const $win = win || Em.$(window);
    const height = $win.height();
    const fromBottom = $win.height() - fromTop;

    if (fromTop < 100 || fromTop + 170 > height) {
      return;
    }

    this.divider.css("bottom", fromBottom - 5);
    this.events.trigger("panelResized", fromBottom);
  },

  didInsertElement() {
    // inspired by http://plugins.jquery.com/misc/textarea.js
    this.divider = Em.$(".divider");

    const $win = Em.$(window);
    let resizing = false;

    const performDrag = e => {
      if (resizing) {
        this.divideView(
          e.clientY || (e.touches && e.touches[0] && e.touches[0].clientY),
          $win
        );
      }
    };

    const endDrag = () => {
      Em.$("#overlay").remove();
      resizing = false;

      if (localStorage) {
        localStorage.logster_divider_bottom = parseInt(
          this.divider.css("bottom"),
          10
        );
      }

      const $document = Em.$(document);
      MOVE_EVENTS.forEach(e => $document.unbind(e, performDrag));
      UP_EVENTS.forEach(e => $document.unbind(e, endDrag));
    };

    this.divider.on(DOWN_EVENTS.join(" "), e => {
      e.preventDefault(); // for disabling pull-down-to-refresh on mobile
      Em.$("<div id='overlay'></div>").appendTo(Em.$("body"));
      resizing = true;
      Em.$(document)
        .on(MOVE_EVENTS.join(" "), _.throttle(performDrag, 25))
        .on(UP_EVENTS.join(" "), endDrag);
    });

    Em.run.next(() => {
      const amount = (localStorage && localStorage.logster_divider_bottom) || 300;
      const fromTop =
        $win.height() - parseInt(amount, 10);
      this.divideView(fromTop, $win);
    });
  },

  willDestroyElement() {
    Em.$(".divider").off(DOWN_EVENTS.join(" "));
  }
});

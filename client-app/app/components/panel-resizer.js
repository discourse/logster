import Component from "@ember/component";

export default Component.extend({
  classNames: ["divider"],

  divideView(fromTop, win) {
    const $win = win || Em.$(window);
    const height = $win.height();
    const fromBottom = $win.height() - fromTop;

    if (fromTop < 100 || fromTop + 100 > height) {
      return;
    }

    this.topPanel.css("bottom", fromBottom + 5);
    this.bottomPanel.css("height", fromBottom - 15);
    this.divider.css("bottom", fromBottom - 5);
  },

  didInsertElement() {
    // inspired by http://plugins.jquery.com/misc/textarea.js
    this.topPanel = Em.$("#top-panel");
    this.divider = Em.$(".divider");
    this.bottomPanel = Em.$("#bottom-panel");

    const $win = Em.$(window);
    let resizing = false;

    const performDrag = e => {
      if (resizing) {
        this.divideView(e.clientY, $win);
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

      Em.$(document)
        .unbind("mousemove", performDrag)
        .unbind("mouseup", endDrag);
    };

    this.divider
      .on("mousedown", () => {
        Em.$("<div id='overlay'></div>").appendTo(Em.$("body"));
        resizing = true;
        Em.$(document)
          .mousemove(_.throttle(performDrag, 25))
          .mouseup(endDrag);
      })
      .append(
        "<div class='line-1'></div><div class='line-2'></div><div class='line-3'></div>"
      );

    Em.run.next(() => {
      if (localStorage && localStorage.logster_divider_bottom) {
        const fromTop =
          $win.height() - parseInt(localStorage.logster_divider_bottom, 10);
        this.divideView(fromTop, $win);
      }
    });
  },

  willDestroyElement() {
    Em.$(".divider").off("mousedown");
  }
});

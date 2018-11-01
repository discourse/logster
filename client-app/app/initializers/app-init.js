import {
  updateHiddenProperty,
  resetTitleCount
} from "client-app/lib/utilities";
import { init } from "client-app/lib/preload";

export function initialize() {
  // config for moment.js
  moment.updateLocale("en", {
    relativeTime: {
      future: "in %s",
      past: "%s ago",
      s: "secs",
      m: "a min",
      mm: "%d mins",
      h: "an hr",
      hh: "%d hrs",
      d: "a day",
      dd: "%d days",
      M: "a mth",
      MM: "%d mths",
      y: "a yr",
      yy: "%d yrs"
    }
  });

  // parse preloaded json
  const dataset = document.getElementById("preloaded-data").dataset;
  init(dataset);

  // setup event for updating document title and title count
  let hiddenProperty;
  let visibilitychange;

  ["", "webkit", "ms", "moz", "ms"].forEach(prefix => {
    const check = prefix + (prefix === "" ? "hidden" : "Hidden");
    if (document[check] !== undefined && !hiddenProperty) {
      hiddenProperty = check;
      visibilitychange = prefix + "visibilitychange";
    }
  });

  updateHiddenProperty(hiddenProperty);
  document.addEventListener(
    visibilitychange,
    () => {
      resetTitleCount();
    },
    false
  );
}

export default {
  initialize
};

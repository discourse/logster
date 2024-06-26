import {
  ajax,
  resetTitleCount,
  updateHiddenProperty,
} from "client-app/lib/utilities";
import { setRootPath } from "client-app/lib/preload";

export async function initialize(app) {
  const config = app.resolveRegistration("config:environment");
  setRootPath(config.rootURL.replace(/\/$/, ""));

  if (config.environment === "development") {
    app.deferReadiness();

    try {
      const data = await ajax("/development-preload.json");
      const elem = document.getElementById("preloaded-data");
      elem.setAttribute("data-preloaded", JSON.stringify(data));
    } catch (xhr) {
      console.error("Fetching preload data failed.", xhr); // eslint-disable-line no-console
    } finally {
      app.advanceReadiness();
    }
  }

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
      yy: "%d yrs",
    },
  });

  // setup event for updating document title and title count
  let hiddenProperty;
  let visibilitychange;

  for (const prefix of ["", "webkit", "ms", "moz", "ms"]) {
    const check = prefix + (prefix === "" ? "hidden" : "Hidden");

    if (document[check] !== undefined) {
      hiddenProperty = check;
      visibilitychange = prefix + "visibilitychange";
      break;
    }
  }

  updateHiddenProperty(hiddenProperty);
  document.addEventListener(visibilitychange, resetTitleCount, false);

  const isMobile =
    /mobile/i.test(navigator.userAgent) && !/iPad/.test(navigator.userAgent);
  if (isMobile) {
    document.body.classList.add("mobile");
  }
}

export default {
  initialize,
};

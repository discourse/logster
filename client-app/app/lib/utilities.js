import Preload from "client-app/lib/preload";

const entityMap = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#39;",
  "/": "&#x2F;"
};

export function escapeHtml(string) {
  return String(string).replace(/[&<>"'/]/g, s => entityMap[s]);
}

export function ajax(url, settings) {
  settings = settings || {};
  settings.headers = settings.headers || {};
  settings.headers["X-SILENCE-LOGGER"] = true;
  return Em.$.ajax(Preload.get("rootPath") + url, settings);
}

export function preloadOrAjax(url, settings) {
  const preloaded = Preload.get(url.replace(".json", ""));
  if (preloaded) {
    return Em.RSVP.resolve(preloaded);
  } else {
    return ajax(url, settings);
  }
}

let HIDDEN_PROPERTY;
let TITLE;
let TITLE_COUNT;

export function updateHiddenProperty(property) {
  HIDDEN_PROPERTY = property;
}

export function isHidden() {
  if (HIDDEN_PROPERTY !== undefined) {
    return document[HIDDEN_PROPERTY];
  } else {
    return !document.hasFocus;
  }
}

export function increaseTitleCount(increment) {
  if (!isHidden()) {
    return;
  }
  TITLE = TITLE || document.title;
  TITLE_COUNT = TITLE_COUNT || 0;
  TITLE_COUNT += increment;
  document.title = `${TITLE} (${TITLE_COUNT})`;
}

export function resetTitleCount() {
  TITLE_COUNT = 0;
  document.title = TITLE || document.title;
}

export function formatTime(timestamp) {
  let formatted;
  const time = moment(timestamp);
  const now = moment();

  if (time.diff(now.startOf("day")) > 0) {
    formatted = time.format("h:mm a");
  } else {
    if (time.diff(now.startOf("week")) > 0) {
      formatted = time.format("dd h:mm a");
    } else {
      if (time.diff(now.startOf("year")) > 0) {
        formatted = time.format("D MMM h:mm a");
      } else {
        formatted = time.format("D MMM YY");
      }
    }
  }

  return formatted;
}

export function buildArrayString(array) {
  const buffer = [];
  array.forEach(v => {
    if (v === null) {
      buffer.push("null");
    } else if (Object.prototype.toString.call(v) === "[object Array]") {
      buffer.push(buildArrayString(v));
    } else {
      buffer.push(escapeHtml(v.toString()));
    }
  });
  return "[" + buffer.join(", ") + "]";
}

export function buildHashString(hash, recurse, expanded = []) {
  if (!hash) return "";

  const buffer = [];
  const hashes = [];
  const expandableKeys = Preload.get("env_expandable_keys") || [];
  _.each(hash, (v, k) => {
    if (v === null) {
      buffer.push("null");
    } else if (Object.prototype.toString.call(v) === "[object Array]") {
      let valueHtml = "";
      if (
        expandableKeys.indexOf(k) !== -1 &&
        !recurse &&
        expanded.indexOf(k) === -1
      ) {
        valueHtml = `${escapeHtml(
          v[0]
        )}, <a class="expand-list" data-key=${k}>${v.length - 1} more</a>`;
      } else {
        valueHtml = buildArrayString(v);
      }
      buffer.push(
        "<tr><td>" + escapeHtml(k) + "</td><td>" + valueHtml + "</td></tr>"
      );
    } else if (typeof v === "object") {
      hashes.push(k);
    } else {
      buffer.push(
        "<tr><td>" + escapeHtml(k) + "</td><td>" + escapeHtml(v) + "</td></tr>"
      );
    }
  });

  if (_.size(hashes) > 0) {
    _.each(hashes, function(k1) {
      const v = hash[k1];
      buffer.push("<tr><td></td><td><table>");
      buffer.push(
        "<td>" +
          escapeHtml(k1) +
          "</td><td>" +
          buildHashString(v, true) +
          "</td>"
      );
      buffer.push("</table></td></tr>");
    });
  }
  const className = recurse ? "" : "env-table";
  return "<table class='" + className + "'>" + buffer.join("\n") + "</table>";
}

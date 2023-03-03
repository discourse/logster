import Preload, { getRootPath } from "client-app/lib/preload";

const entityMap = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#39;",
  "/": "&#x2F;",
};

export function escapeHtml(string) {
  return String(string).replace(/[&<>"'/]/g, (s) => entityMap[s]);
}

export function ajax(url, settings) {
  // eslint-disable-next-line no-restricted-globals
  return new Promise((resolve, reject) => {
    settings ||= {};
    const xhr = new XMLHttpRequest();
    url = getRootPath() + url;

    if (settings.data) {
      for (const [param, value] of Object.entries(settings.data)) {
        url += url.includes("?") ? "&" : "?";
        url += `${param}=${encodeURIComponent(value)}`;
      }
    }

    xhr.open(settings.method || settings.type || "GET", url);
    xhr.setRequestHeader("X-SILENCE-LOGGER", true);

    if (settings.headers) {
      for (const [header, value] of Object.entries(settings.headers)) {
        xhr.setRequestHeader(header, value);
      }
    }

    xhr.onreadystatechange = () => {
      if (xhr.readyState === 4) {
        let status = xhr.status;
        if ((status >= 200 && status < 300) || status === 304) {
          const type = xhr.getResponseHeader("Content-Type");
          let data = xhr.responseText;
          if (/\bjson\b/.test(type)) {
            data = JSON.parse(data);
          }
          resolve(data);
        } else {
          reject(xhr);
        }
      }
    };

    xhr.send();
  });
}

export async function preloadOrAjax(url, settings) {
  const preloaded = Preload.get(url.replace(".json", ""));
  if (preloaded) {
    return preloaded;
  } else {
    return await ajax(url, settings);
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

  TITLE ||= document.title;
  TITLE_COUNT ||= 0;
  TITLE_COUNT += increment;
  document.title = `${TITLE} (${TITLE_COUNT})`;
}

export function resetTitleCount() {
  TITLE_COUNT = 0;
  document.title = TITLE || document.title;
}

export function formatTime(timestamp) {
  const time = moment(timestamp);
  const now = moment();

  if (time.diff(now.startOf("day")) > 0) {
    return time.format("h:mm a");
  } else if (time.diff(now.startOf("week")) > 0) {
    return time.format("dd h:mm a");
  } else if (time.diff(now.startOf("year")) > 0) {
    return time.format("D MMM h:mm a");
  } else {
    return time.format("D MMM YY");
  }
}

export function buildArrayString(array) {
  const buffer = array.map((v) => {
    if (v === null) {
      return "null";
    } else if (Array.isArray(v)) {
      return buildArrayString(v);
    } else {
      return escapeHtml(v.toString());
    }
  });

  return "[" + buffer.join(", ") + "]";
}

export function buildHashString(hash, recurse, expanded = []) {
  if (!hash) {
    return "";
  }

  const buffer = [];
  const hashes = [];
  const expandableKeys = Preload.get("env_expandable_keys") || [];

  for (const [k, v] of Object.entries(hash)) {
    if (v === null) {
      buffer.push("null");
    } else if (Object.prototype.toString.call(v) === "[object Array]") {
      let valueHtml = "";
      if (
        expandableKeys.includes(k) &&
        !recurse &&
        !expanded.includes(k) &&
        v.length > 3
      ) {
        valueHtml = `${escapeHtml(
          v[0]
        )}, <a class="expand-list" data-key=${k}>${v.length - 1} more</a>`;
      } else {
        valueHtml = `${escapeHtml(v[0])}, ${buildArrayString(
          v.slice(1, v.length)
        )}`;
      }
      buffer.push(`<tr><td>${escapeHtml(k)}</td><td>${valueHtml}</td></tr>`);
    } else if (typeof v === "object") {
      hashes.push(k);
    } else {
      if (k === "time" && typeof v === "number") {
        const title = moment(v).format();
        const time = formatTime(v);
        buffer.push(`<tr title="${title}"><td>${k}</td><td>${time}</td></tr>`);
      } else {
        buffer.push(
          `<tr><td>${escapeHtml(k)}</td><td>${escapeHtml(v)}</td></tr>`
        );
      }
    }
  }

  for (const k1 of hashes) {
    const v = hash[k1];
    buffer.push("<tr><td></td><td><table>");
    buffer.push(
      `<td>${escapeHtml(k1)}</td><td>${buildHashString(v, true)}</td>`
    );
    buffer.push("</table></td></tr>");
  }

  const className = recurse ? "" : "env-table";
  return `<table class='${className}'>${buffer.join("\n")}</table>`;
}

export function clone(object) {
  // simple function to clone an object
  // we don't need it fancier than this
  const copy = {};
  for (const [k, v] of Object.entries(object)) {
    copy[k] = v;
  }
  return copy;
}

export function setLocalStorage(key, value) {
  try {
    if (window.localStorage) {
      key = "logster-" + key;
      window.localStorage.setItem(key, value);
    }
  } catch {
    /* do nothing */
  }
}

export function getLocalStorage(key, fallback) {
  try {
    if (window.localStorage) {
      key = "logster-" + key;
      const value = window.localStorage.getItem(key);
      if (value === null) {
        // key doesn't exist
        return fallback;
      }
      if (value === "true") {
        return true;
      }
      if (value === "false") {
        return false;
      }
      // Add more cases here for numbers, null, undefined etc. as/when needed
      return value;
    } else {
      return fallback;
    }
  } catch {
    return fallback;
  }
}

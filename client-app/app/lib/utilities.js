import { default as Preload, getRootPath } from "client-app/lib/preload";
import { Promise, resolve } from "rsvp";

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
  return new Promise((resolve, reject) => {
    settings = settings || {};
    const xhr = new XMLHttpRequest();
    url = getRootPath() + url;
    if (settings.data) {
      for (let param in settings.data) {
        const prefix = url.indexOf("?") === -1 ? "?" : "&";
        url += prefix;
        url += `${param}=${encodeURIComponent(settings.data[param])}`;
      }
    }
    xhr.open(settings.method || settings.type || "GET", url);
    xhr.setRequestHeader("X-SILENCE-LOGGER", true);
    if (settings.headers) {
      for (let header in settings.headers) {
        xhr.setRequestHeader(header, settings.headers[header]);
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

export function preloadOrAjax(url, settings) {
  const preloaded = Preload.get(url.replace(".json", ""));
  if (preloaded) {
    return resolve(preloaded);
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
  Object.keys(hash).forEach(k => {
    const v = hash[k];
    if (v === null) {
      buffer.push("null");
    } else if (Object.prototype.toString.call(v) === "[object Array]") {
      let valueHtml = "";
      if (
        expandableKeys.indexOf(k) !== -1 &&
        !recurse &&
        expanded.indexOf(k) === -1 &&
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
  });

  if (hashes.length > 0) {
    hashes.forEach(k1 => {
      const v = hash[k1];
      buffer.push("<tr><td></td><td><table>");
      buffer.push(
        `<td>${escapeHtml(k1)}</td><td>${buildHashString(v, true)}</td>`
      );
      buffer.push("</table></td></tr>");
    });
  }
  const className = recurse ? "" : "env-table";
  return `<table class='${className}'>${buffer.join("\n")}</table>`;
}

export function clone(object) {
  // simple function to clone an object
  // we don't need it fancier than this
  const copy = {};
  Object.keys(object).forEach(k => {
    copy[k] = object[k];
  });
  return copy;
}

export function setLocalStorage(key, value) {
  try {
    if (window.localStorage) {
      key = "logster-" + key;
      window.localStorage.setItem(key, value);
    }
  } catch { /* do nothing */ }
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

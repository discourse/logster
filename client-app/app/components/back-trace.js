import Component from "@ember/component";
import Preloaded from "client-app/lib/preload";
import { escapeHtml } from "client-app/lib/utilities";
import { computed } from "@ember/object";

const COLLAPSED_HTML = `<span class="expand noselect">… </span>`;
const EXPANDED_HTML = `<span class="noselect">  </span>`;

function startsWith(str, search) {
  if (!str || !search || search.length > str.length) {
    return false;
  }
  return str.substring(0, search.length) == search;
}

function backtraceLinksEnabled() {
  return Preloaded.get("backtrace_links_enabled");
}

function appendSlash(str) {
  if (str && str[str.length - 1] !== "/") {
    return str + "/";
  } else {
    return str;
  }
}

function assembleURL({ repo, path, filename, lineNumber, versionHash = null }) {
  let url = appendSlash(repo);
  if (!/\/tree\//.test(url)) {
    url += "blob/";
    url += versionHash ? `${versionHash}/` : "master/";
  }
  url += path + filename;
  if (/^[0-9]+$/.test(lineNumber)) {
    url += `#L${lineNumber}`;
  }
  return url;
}

function parseGemLine(line, expand = false) {
  const gemsDir = Preloaded.get("gems_dir");
  const lineWithoutGemDir = line.substring(gemsDir.length);

  const regexResults = lineWithoutGemDir.match(
    /([^/]+)\/(.+\/)(.+):(\d+)(:.*)/
  );

  const [, gemWithVersion, path, filename, lineNumber, remaining] =
    regexResults || [];

  const beforeURLContent = expand
    ? `${gemsDir}${gemWithVersion}/${path}`
    : `${gemWithVersion}/${path}`;
  const URLContent = filename;
  const afterURLContent = `:${lineNumber}${remaining}`;

  const result = {
    url: null,
    beforeURLContent,
    URLContent,
    afterURLContent
  };

  if (!backtraceLinksEnabled()) {
    return result;
  }

  const gemsData = Preloaded.get("gems_data");
  const match = gemsData
    .filter(g => startsWith(gemWithVersion, `${g.name}-`))
    .sortBy("name.length")
    .reverse()[0];

  if (match) {
    const url = assembleURL({ repo: match.url, path, filename, lineNumber });
    Em.$.extend(result, { url });
  }
  return result;
}

function parseAppLine(line) {
  const result = {
    url: null,
    beforeURLContent: "",
    URLContent: line,
    afterURLContent: ""
  };

  if (!backtraceLinksEnabled()) {
    return result;
  }

  const projectDirs = Preloaded.get("directories");

  const match = projectDirs
    .filter(dir => startsWith(line, dir.path))
    .sortBy("path.length")
    .reverse()[0];

  if (match) {
    const root = appendSlash(match.path);
    const lineWithoutRoot = line.substring(root.length);

    let path = "",
      filename,
      lineNumber,
      remaining;

    const hasSlash = lineWithoutRoot.indexOf("/") !== -1;
    const regex = hasSlash ? /(.+\/)(.+):(\d+)(:.*)/ : /(.+):(\d+)(:.*)/;

    if (hasSlash) {
      [, path, filename, lineNumber, remaining] =
        lineWithoutRoot.match(regex) || [];
    } else {
      [, filename, lineNumber, remaining] = lineWithoutRoot.match(regex) || [];
    }

    if (filename && lineNumber && remaining) {
      const versionHash = match.main_app
        ? Preloaded.get("application_version")
        : null;

      const url = assembleURL({
        repo: match.url,
        path,
        filename,
        lineNumber,
        versionHash
      });

      const beforeURLContent = `${root}${path}`;
      const URLContent = filename;
      const afterURLContent = `:${lineNumber}${remaining}`;

      Em.$.extend(result, {
        url,
        beforeURLContent,
        URLContent,
        afterURLContent
      });
    }
  }
  return result;
}

function parseLine(line, expand = false) {
  const isGem = startsWith(line, Preloaded.get("gems_dir"));
  let result = {};

  if (isGem) {
    result = parseGemLine(line, expand);
  } else {
    result = parseAppLine(line);
  }

  Object.keys(result).forEach(key => {
    const currentValue = result[key];
    result[key] =
      typeof currentValue === "string" ? escapeHtml(result[key]) : currentValue;
  });

  return result;
}

function generateLineHTML(line, { expand = false } = {}) {
  const isGem = startsWith(line, Preloaded.get("gems_dir"));

  let html = `<div class="backtrace-line" data-line="${escapeHtml(line)}">`;
  html += !isGem || expand ? EXPANDED_HTML : COLLAPSED_HTML;

  const { url, beforeURLContent, URLContent, afterURLContent } = parseLine(
    line,
    expand
  );

  if (url) {
    html += `<span>${beforeURLContent}<a target="_blank" href="${url}">${URLContent}</a>${afterURLContent}</span>`;
  } else {
    html += `<span>${beforeURLContent + URLContent + afterURLContent}</span>`;
  }

  html += `</div>`;
  return html;
}

export default Component.extend({
  htmlContent: computed("backtrace", function() {
    const backtrace = this.get("backtrace");
    if (backtrace) {
      return backtrace
        .split("\n")
        .map(line => generateLineHTML(line))
        .join("");
    } else {
      return "";
    }
  }),

  click(e) {
    const { target } = e;
    if (target.classList.contains("expand")) {
      const line = target.parentElement;
      const backtraceLine = line.dataset.line;
      if (backtraceLine) {
        const newLineContent = generateLineHTML(backtraceLine, {
          expand: true
        });
        const newLine = document.createElement("DIV");
        newLine.innerHTML = newLineContent;
        line.parentElement.replaceChild(newLine, line);
      }
    }
  }
});

import Component from "@ember/component";
import Preloaded from "client-app/lib/preload";
import { computed } from "@ember/object";

function startsWith(str, search) {
  if (!str || !search || search.length > str.length) {
    return false;
  }
  return str.substring(0, search.length) === search;
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

function assembleURL({ repo, path, filename, lineNumber, commitSha = null }) {
  let url = appendSlash(repo);
  if (!/\/tree\//.test(url)) {
    url += "blob/";
    url += commitSha ? `${commitSha}/` : "master/";
  }
  url += path + filename;
  if (/^[0-9]+$/.test(lineNumber)) {
    url += `#L${lineNumber}`;
  }
  return url;
}

function shortenLine(line) {
  const isGem = startsWith(line, Preloaded.get("gems_dir"));
  if (isGem) {
    const gemsDir = Preloaded.get("gems_dir");
    return line.substring(gemsDir.length);
  } else {
    return line;
  }
}

export default Component.extend({
  GithubURLForGem(line) {
    let url = null;
    if (!backtraceLinksEnabled()) {
      return url;
    }

    const regexResults = line.match(/([^/]+)\/(.+\/)(.+):(\d+):.*/);
    const [, gemWithVersion, path, filename, lineNumber] = regexResults || [];
    const gemsData = Preloaded.get("gems_data");
    const match = gemsData
      .filter(g => startsWith(gemWithVersion, `${g.name}-`))
      .sortBy("name.length")
      .reverse()[0];

    if (match) {
      url = assembleURL({ repo: match.url, path, filename, lineNumber });
    }
    return url;
  },

  GithubURLForApp(line) {
    let url = null;

    if (!backtraceLinksEnabled()) {
      return url;
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
        [, filename, lineNumber, remaining] =
          lineWithoutRoot.match(regex) || [];
      }

      if (filename && lineNumber && remaining) {
        const commitSha = match.main_app ? this.commitSha : null;

        url = assembleURL({
          repo: match.url,
          path,
          filename,
          lineNumber,
          commitSha
        });
      }
    }
    return url;
  },

  findGithubURL(line, shortenedLine) {
    const projectDirs = Preloaded.get("directories") || [];
    const isGem = startsWith(line, Preloaded.get("gems_dir"));
    const isApp = projectDirs.some(p => startsWith(line, p.path));
    if (isGem || !isApp) {
      return this.GithubURLForGem(shortenedLine);
    } else {
      return this.GithubURLForApp(line);
    }
  },

  commitSha: computed("env", function() {
    let env = null;
    if (Array.isArray(this.env)) {
      env = this.env.map(e => e.application_version).filter(e => e)[0];
    } else if (this.env) {
      env = this.env.application_version;
    }
    return env || Preloaded.get("application_version");
  }),

  lines: computed("backtrace", "commitSha", function() {
    if (!this.backtrace || this.backtrace.length === 0) {
      return [];
    }
    return this.backtrace.split("\n").map(line => {
      const shortenedLine = shortenLine(line);
      return {
        line: shortenedLine,
        url: this.findGithubURL(line, shortenedLine)
      };
    });
  })
});

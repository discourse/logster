import classic from "ember-classic-decorator";
import { computed } from "@ember/object";
import Component from "@ember/component";
import Preloaded from "client-app/lib/preload";

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
  const isGem = line.startsWith(Preloaded.get("gems_dir"));

  if (isGem) {
    const gemsDir = Preloaded.get("gems_dir");
    return line.substring(gemsDir.length);
  } else {
    return line;
  }
}

@classic
export default class BackTrace extends Component {
  @computed("env.application_version")
  get commitSha() {
    let sha = null;

    if (Array.isArray(this.env)) {
      sha = this.env.map((e) => e.application_version).filter((e) => e)[0];
    } else if (this.env) {
      sha = this.env.application_version;
    }

    return sha || Preloaded.get("application_version");
  }

  @computed("backtrace.length", "commitSha")
  get lines() {
    if (!this.backtrace || this.backtrace.length === 0) {
      return [];
    }

    return this.backtrace.split("\n").map((line) => {
      const shortenedLine = shortenLine(line);
      return {
        line: shortenedLine,
        url: this.findGithubURL(line, shortenedLine),
      };
    });
  }

  githubURLForGem(line) {
    if (!Preloaded.get("backtrace_links_enabled")) {
      return null;
    }

    const regexResults = line.match(/([^/]+)\/(.+\/)(.+):(\d+):.*/);
    const [, gemWithVersion, path, filename, lineNumber] = regexResults || [];
    const gemsData = Preloaded.get("gems_data");
    const match = gemsData
      .filter((g) => gemWithVersion.startsWith(`${g.name}-`))
      .sortBy("name.length")
      .reverse()[0];

    if (!match) {
      return null;
    }

    return assembleURL({ repo: match.url, path, filename, lineNumber });
  }

  githubURLForApp(line) {
    if (!Preloaded.get("backtrace_links_enabled")) {
      return null;
    }

    const projectDirs = Preloaded.get("directories");
    const match = projectDirs
      .filter((dir) => line.startsWith(dir.path))
      .sortBy("path.length")
      .reverse()[0];

    if (!match) {
      return null;
    }

    const root = appendSlash(match.path);
    const lineWithoutRoot = line.substring(root.length);
    const hasSlash = lineWithoutRoot.includes("/");
    let path = "";
    let filename;
    let lineNumber;
    let remaining;

    if (hasSlash) {
      [, path, filename, lineNumber, remaining] =
        lineWithoutRoot.match(/(.+\/)(.+):(\d+)(:.*)/) || [];
    } else {
      [, filename, lineNumber, remaining] =
        lineWithoutRoot.match(/(.+):(\d+)(:.*)/) || [];
    }

    if (!filename || !lineNumber || !remaining) {
      return null;
    }

    const commitSha = match.main_app ? this.commitSha : null;

    return assembleURL({
      repo: match.url,
      path,
      filename,
      lineNumber,
      commitSha,
    });
  }

  findGithubURL(line, shortenedLine) {
    const projectDirs = Preloaded.get("directories") || [];
    const isGem = line.startsWith(Preloaded.get("gems_dir"));
    const isApp = projectDirs.some((p) => line.startsWith(p.path));

    if (isGem || !isApp) {
      return this.githubURLForGem(shortenedLine);
    } else {
      return this.githubURLForApp(line);
    }
  }
}

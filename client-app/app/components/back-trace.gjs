import Component from "@glimmer/component";
import FaIcon from "@fortawesome/ember-fontawesome/components/fa-icon";
import Preloaded from "client-app/lib/preload";

function appendSlash(str) {
  if (str && str[str.length - 1] !== "/") {
    return `${str}/`;
  }
  return str;
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
  const gemsDir = Preloaded.get("gems_dir");
  return line.startsWith(gemsDir) ? line.substring(gemsDir.length) : line;
}

export default class BackTrace extends Component {
  get commitSha() {
    let sha = null;
    const env = this.args.env;

    if (Array.isArray(env)) {
      sha = env.map((item) => item.application_version).find(Boolean);
    } else if (env) {
      sha = env.application_version;
    }

    return sha || Preloaded.get("application_version");
  }

  get lines() {
    const backtrace = this.args.backtrace;
    if (!backtrace) {
      return [];
    }

    return backtrace.split("\n").map((line) => {
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

    const [, gemWithVersion, path, filename, lineNumber] =
      line.match(/([^/]+)\/(.+\/)(.+):(\d+):.*/) || [];
    if (!gemWithVersion) {
      return null;
    }

    const match = Preloaded.get("gems_data")
      .filter((gem) => gemWithVersion.startsWith(`${gem.name}-`))
      .sort((a, b) => b.name.length - a.name.length)[0];

    return match
      ? assembleURL({ repo: match.url, path, filename, lineNumber })
      : null;
  }

  githubURLForApp(line) {
    if (!Preloaded.get("backtrace_links_enabled")) {
      return null;
    }

    const match = Preloaded.get("directories")
      .filter((directory) => line.startsWith(directory.path))
      .sort((a, b) => b.path.length - a.path.length)[0];

    if (!match) {
      return null;
    }

    const lineWithoutRoot = line.substring(appendSlash(match.path).length);
    let path = "";
    let filename;
    let lineNumber;
    let remaining;

    if (lineWithoutRoot.includes("/")) {
      [, path, filename, lineNumber, remaining] =
        lineWithoutRoot.match(/(.+\/)(.+):(\d+)(:.*)/) || [];
    } else {
      [, filename, lineNumber, remaining] =
        lineWithoutRoot.match(/(.+):(\d+)(:.*)/) || [];
    }

    if (!filename || !lineNumber || !remaining) {
      return null;
    }

    return assembleURL({
      repo: match.url,
      path,
      filename,
      lineNumber,
      commitSha: match.main_app ? this.commitSha : null,
    });
  }

  findGithubURL(line, shortenedLine) {
    const projectDirs = Preloaded.get("directories") || [];
    const isGem = line.startsWith(Preloaded.get("gems_dir"));
    const isApp = projectDirs.some((project) => line.startsWith(project.path));

    return isGem || !isApp
      ? this.githubURLForGem(shortenedLine)
      : this.githubURLForApp(line);
  }

  <template>
    {{~#each this.lines as |line|~}}
      <div class="backtrace-line">
        {{~line.line~}}
        {{~#if line.url~}}
          <a
            href={{line.url}}
            target="_blank"
            class="line-link"
            rel="noopener noreferrer"
          >
            <FaIcon @icon="external-link-square-alt" />
          </a>
        {{~/if~}}
      </div>
    {{~/each~}}
  </template>
}

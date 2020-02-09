let CONTAINER = {};
let isInitialized = false;
let rootPath;

export function setRootPath(path) {
  rootPath = path;
}

export function getRootPath() {
  return rootPath;
}

// exported so that it can be used in tests
export function init() {
  const dataset = document.getElementById("preloaded-data").dataset;
  CONTAINER = JSON.parse(dataset.preloaded);
  CONTAINER.rootPath = rootPath;
  isInitialized = true;
}

export default {
  get(key) {
    if (!isInitialized) {
      init();
    }
    return Em.get(CONTAINER, key);
  }
};

// used in tests
export function mutatePreload(key, value) {
  if (!isInitialized) {
    init();
  }
  Em.set(CONTAINER, key, value);
}

export function uninitialize() {
  isInitialized = false;
}

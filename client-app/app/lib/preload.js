let CONTAINER;
let isInitialized = false;

// exported so that it can be used in tests
export function init() {
  const dataset = document.getElementById("preloaded-data").dataset;
  CONTAINER = Em.$.extend(JSON.parse(dataset.preloaded), {
    rootPath: dataset.rootPath
  });
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

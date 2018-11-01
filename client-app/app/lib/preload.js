let CONTAINER;

export function init(dataset) {
  CONTAINER = {
    rootPath: dataset.rootPath,
    preload: JSON.parse(dataset.preloaded)
  };
}

export default {
  get(key) {
    return CONTAINER[key];
  }
};

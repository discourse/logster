export function bound(target, key, desc) {
  const orig = desc.value;
  const boundKey = `_${key}Bound`;
  return {
    get() {
      if (this[boundKey]) return this[boundKey];
      this.set(boundKey, orig.bind(this));
      return this[boundKey];
    }
  };
}

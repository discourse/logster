import { default as EmberObject, computed } from "@ember/object";

export default EmberObject.extend({
  isNew: false,
  value: "",
  valueBuffer: "",
  error: null,
  saving: false,
  count: 0,

  init() {
    this._super(...arguments);
    this.set("valueBuffer", this.value);
  },

  updateValue(newValue) {
    this.setProperties({
      value: newValue,
      valueBuffer: newValue,
    });
  },

  hasBuffer: computed("value", "valueBuffer", function () {
    return this.value !== this.valueBuffer;
  }),

  zeroCount: computed.lte("count", 0),
});

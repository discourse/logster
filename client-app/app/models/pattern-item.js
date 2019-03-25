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
    this.set("valueBuffer", this.get("value"));
  },

  updateValue(newValue) {
    this.setProperties({
      value: newValue,
      valueBuffer: newValue
    });
  },

  hasBuffer: computed("value", "valueBuffer", function() {
    return this.get("value") !== this.get("valueBuffer");
  }),

  zeroCount: computed("count", function() {
    return this.get("count") <= 0;
  })
});

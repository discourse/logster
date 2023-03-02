import EmberObject, { computed } from "@ember/object";
import { lte } from "@ember/object/computed";

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

  zeroCount: lte("count", 0),
});

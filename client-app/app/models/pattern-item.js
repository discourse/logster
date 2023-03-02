import classic from "ember-classic-decorator";
import { lte } from "@ember/object/computed";
import EmberObject, { computed } from "@ember/object";

@classic
export default class PatternItem extends EmberObject {
  isNew = false;
  value = "";
  valueBuffer = "";
  error = null;
  saving = false;
  count = 0;

  @lte("count", 0) zeroCount;

  init() {
    super.init(...arguments);
    this.set("valueBuffer", this.value);
  }

  @computed("value", "valueBuffer")
  get hasBuffer() {
    return this.value !== this.valueBuffer;
  }

  updateValue(newValue) {
    this.setProperties({
      value: newValue,
      valueBuffer: newValue,
    });
  }
}

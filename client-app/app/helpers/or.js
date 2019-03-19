import { helper } from "@ember/component/helper";

export function or(params) {
  return params.some(p => p);
}

export default helper(or);

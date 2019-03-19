import { helper } from "@ember/component/helper";
import Preload from "client-app/lib/preload";

export function logsterUrl(arr) {
  let url = arr[0];
  if (url[0] !== "/") {
    url = `/${url}`;
  }
  return Preload.get("rootPath") + url;
}

export default helper(logsterUrl);

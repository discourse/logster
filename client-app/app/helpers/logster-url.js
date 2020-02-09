import { helper } from "@ember/component/helper";
import { getRootPath } from "client-app/lib/preload";

export function logsterUrl(arr) {
  let url = arr[0];
  if (url[0] !== "/") {
    url = `/${url}`;
  }
  return getRootPath() + url;
}

export default helper(logsterUrl);

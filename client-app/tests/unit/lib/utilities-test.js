import { module, test } from "qunit";
import {
  applyRequestHeaders,
  getLocalStorage,
  setLocalStorage,
} from "client-app/lib/utilities";

module("Unit | Lib | utilities", function () {
  test("ajax request headers include Logster CSRF protection", function (assert) {
    const headers = {};
    const request = {
      setRequestHeader(name, value) {
        headers[name] = value;
      },
    };

    applyRequestHeaders(request, {
      headers: {
        "X-Custom-Header": "custom value",
        "X-Requested-With": "overridden",
      },
    });

    assert.strictEqual(
      headers["X-Requested-With"],
      "XMLHttpRequest",
      "adds the CSRF header"
    );
    assert.strictEqual(headers["X-SILENCE-LOGGER"], true, "preserves the logger header");
    assert.strictEqual(headers["X-Custom-Header"], "custom value", "applies caller headers");
  });

  test("storage helpers can preserve a legacy raw key", function (assert) {
    const key = "logster_test_raw_key";

    try {
      setLocalStorage(key, "stored", false);
      assert.strictEqual(getLocalStorage(key, null, false), "stored");
      assert.strictEqual(window.localStorage.getItem(key), "stored");
    } finally {
      window.localStorage.removeItem(key);
    }
  });
});

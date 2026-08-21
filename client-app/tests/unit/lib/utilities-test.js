import { module, test } from "qunit";
import { applyRequestHeaders } from "client-app/lib/utilities";

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
});

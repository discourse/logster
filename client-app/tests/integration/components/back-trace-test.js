import { module, test } from "qunit";
import { setupRenderingTest } from "ember-qunit";
import { render, find, findAll } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";

module("Integration | Component | back-trace", function(hooks) {
  setupRenderingTest(hooks);

  test("backtrace lines display and work correctly", async function(assert) {
    const backtrace = `/var/www/discourse/vendor/bundle/ruby/2.6.0/gems/activerecord-6.0.1/lib/active_record/relation/finder_methods.rb:317:in \`exists?'
/var/www/discourse/lib/permalink_constraint.rb:6:in \`matches?'
/var/www/discourse/plugins/discourse-prometheus/lib/middleware/metrics.rb:17:in \`call'`;
    this.set("backtrace", backtrace);
    await render(hbs`{{back-trace backtrace=backtrace}}`);

    const [gem, app, plugin] = findAll("a");
    assert.equal(
      gem.href,
      "https://github.com/rails/rails/tree/v6.0.1/activerecord/lib/active_record/relation/finder_methods.rb#L317"
    );

    assert.equal(
      app.href,
      "https://github.com/discourse/discourse/blob/ce512452b512b909c38e9c63f2a0e1f8c17a2399/lib/permalink_constraint.rb#L6"
    );

    assert.equal(
      plugin.href,
      "https://github.com/discourse/discourse-prometheus/blob/master/lib/middleware/metrics.rb#L17"
    );

    let gemLine = find("div.backtrace-line");
    assert.equal(
      gemLine.textContent,
      "activerecord-6.0.1/lib/active_record/relation/finder_methods.rb:317:in `exists?'",
      "gem lines are truncated"
    );
  });

  test("non-ruby backtraces don't break things", async function(assert) {
    this.set(
      "backtrace",
      `m/<@https://discourse-cdn.com/assets/application-f59d2.br.js:1:27448
m@https://discourse-cdn.com/assets/application-f59d2.br.js:1:27560
string@https://discourse-cdn.com/assets/application-f59d2.br.js:1:27869`
    );
    await render(hbs`{{back-trace backtrace=backtrace}}`);
    const lines = this.backtrace.split("\n");
    findAll("div.backtrace-line").forEach((node, index) => {
      assert.equal(node.textContent.trim(), lines[index]);
    });
  });
});

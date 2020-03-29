import { module, test } from "qunit";
import { setupRenderingTest } from "ember-qunit";
import { render, find, findAll } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { uninitialize, mutatePreload } from "client-app/lib/preload";

module("Integration | Component | back-trace", function(hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function() {
    uninitialize();
  });

  hooks.afterEach(function() {
    uninitialize();
  });

  test("backtrace lines display and work correctly", async function(assert) {
    const backtrace = `/var/www/discourse/vendor/bundle/ruby/2.6.0/gems/activerecord-6.0.1/lib/active_record/relation/finder_methods.rb:317:in \`exists?'
/var/www/discourse/lib/permalink_constraint.rb:6:in \`matches?'
/var/www/discourse/plugins/discourse-prometheus/lib/middleware/metrics.rb:17:in \`call'
activerecord-6.0.1/lib/active_record/relation/finder_methods.rb:317:in \`exists?'`;
    this.set("backtrace", backtrace);
    await render(hbs`{{back-trace backtrace=backtrace}}`);

    const [gem, app, plugin, gem2] = findAll("a");
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

    assert.equal(
      gem2.href,
      "https://github.com/rails/rails/tree/v6.0.1/activerecord/lib/active_record/relation/finder_methods.rb#L317"
    );

    let gemLine = find("div.backtrace-line");
    assert.equal(
      gemLine.textContent.trim(),
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

  test("Github links use commit sha", async function(assert) {
    const backtrace = `/var/www/discourse/lib/permalink_constraint.rb:6:in \`matches?'`;
    let env = [
      { application_version: "123abc" },
      { application_version: "abc123" }
    ];
    this.setProperties({
      backtrace,
      env
    });
    await render(hbs`{{back-trace backtrace=backtrace env=env}}`);
    let href = find("a").href;
    assert.equal(
      href,
      "https://github.com/discourse/discourse/blob/123abc/lib/permalink_constraint.rb#L6",
      "uses the first application_version if there are multiple versions"
    );

    env = { application_version: "567def" };
    this.set("env", env);
    await render(hbs`{{back-trace backtrace=backtrace env=env}}`);
    href = find("a").href;
    assert.equal(
      href,
      "https://github.com/discourse/discourse/blob/567def/lib/permalink_constraint.rb#L6",
      "uses application_version when env is only a hash"
    );

    this.set("env", null);
    await render(hbs`{{back-trace backtrace=backtrace env=env}}`);
    href = find("a").href;
    assert.equal(
      href,
      "https://github.com/discourse/discourse/blob/ce512452b512b909c38e9c63f2a0e1f8c17a2399/lib/permalink_constraint.rb#L6",
      "falls back to preload if env doesn't contain application_version"
    );

    mutatePreload("application_version", null);
    await render(hbs`{{back-trace backtrace=backtrace}}`);
    href = find("a").href;
    assert.equal(
      href,
      "https://github.com/discourse/discourse/blob/master/lib/permalink_constraint.rb#L6",
      "falls back to master branch when neither preload nor application_version in env are available"
    );
  });
});

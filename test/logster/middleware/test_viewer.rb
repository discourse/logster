# frozen_string_literal: true

require_relative "../../test_helper"
require "rack"
require "logster/redis_store"
require "logster/middleware/viewer"

class TestViewer < Minitest::Test
  class BrokenApp
    def call(env)
      [500, {}, ["broken"]]
    end
  end

  class BrowserRequest < Rack::MockRequest
    def request(method, uri, opts = {})
      opts = {
        "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
        "HTTP_SEC_FETCH_SITE" => "same-origin",
      }.merge(opts)
      super
    end
  end

  def setup
    Logster.config.subdirectory = "/logsie"
    Logster.config.authorize_request = nil
    Logster.store = Logster::RedisStore.new
    Logster.store.clear_all
  end

  def teardown
    Logster.config.subdirectory = nil
    Logster.config.authorize_request = nil
    Logster.store.clear_all
    Logster.store = nil
  end

  def viewer
    @viewer ||= Logster::Middleware::Viewer.new(nil)
  end

  def request
    @request ||= BrowserRequest.new(Rack::Lint.new(viewer))
  end

  def raw_request
    @raw_request ||= Rack::MockRequest.new(Rack::Lint.new(viewer))
  end

  def test_path_resolution
    assert_nil(viewer.send(:resolve_path, "/logs"))
    assert_nil(viewer.send(:resolve_path, "/admin/logsie"))
    assert_nil(viewer.send(:resolve_path, "/admin/logsie/bla"))
    assert_equal("/", viewer.send(:resolve_path, "/logsie"))
    assert_equal("/", viewer.send(:resolve_path, "/logsie/"))
    assert_equal("/hello/world", viewer.send(:resolve_path, "/logsie/hello/world"))
  end

  def test_mutating_message_endpoints_require_their_declared_methods
    message =
      Logster.store.report(
        Logger::WARN,
        "test",
        "mutating message",
        backtrace: "example.rb:1",
        env: {
          "application_version" => "abc123",
        },
      )
    Logster.store.protect(message.key)

    cases = {
      "/logsie/message/#{message.key}" => "DELETE",
      "/logsie/protect/#{message.key}" => "PUT",
      "/logsie/unprotect/#{message.key}" => "DELETE",
      "/logsie/solve/#{message.key}" => "PUT",
      "/logsie/clear" => "POST",
      "/logsie/reset-count.json" => "PUT",
      "/logsie/solve-group" => "POST",
    }

    cases.each do |path, allowed_method|
      response = request.get(path)
      assert_equal(405, response.status, "GET #{path} should be rejected")
      assert_equal(allowed_method, response.headers["allow"])
    end

    assert(Logster.store.get(message.key), "rejected requests must not delete or solve the message")
    assert(
      Logster.store.get(message.key).protected,
      "rejected requests must not unprotect the message",
    )
  end

  def test_pattern_endpoint_reports_all_allowed_methods
    Logster.config.enable_custom_patterns_via_ui = true

    response = request.get("/logsie/patterns/suppression.json")

    assert_equal(405, response.status)
    assert_equal("POST, PUT, DELETE", response.headers["allow"])
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_prefixed_paths_cannot_bypass_mutating_route_guards
    Logster.config.enable_custom_patterns_via_ui = true
    message = Logster.store.report(Logger::WARN, "test", "must survive prefixed routes")

    clear_response = raw_request.post("/logsie/prefix/clear")
    solve_response = raw_request.get("/logsie/prefix/solve/#{message.key}")
    pattern_response =
      raw_request.post(
        "/logsie/prefix/patterns/suppression.json",
        params: {
          pattern: "hide everything",
          retroactive: true,
        },
      )

    assert_equal(404, clear_response.status)
    assert_equal(404, solve_response.status)
    assert_equal(404, pattern_response.status)
    assert(Logster.store.get(message.key))
    assert_empty(Logster::SuppressionPattern.find_all)
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_mutating_endpoints_require_csrf_header
    message = Logster.store.report(Logger::WARN, "test", "csrf protected")
    Logster.store.protect(message.key)

    cases = [
      ["DELETE", "/logsie/message/#{message.key}"],
      ["PUT", "/logsie/protect/#{message.key}"],
      ["DELETE", "/logsie/unprotect/#{message.key}"],
      ["PUT", "/logsie/solve/#{message.key}"],
      %w[POST /logsie/clear],
      %w[PUT /logsie/reset-count.json],
      %w[POST /logsie/solve-group],
      %w[POST /logsie/patterns/suppression.json],
      %w[PUT /logsie/patterns/suppression.json],
      %w[DELETE /logsie/patterns/suppression.json],
    ]

    cases.each do |method, path|
      response = raw_request.request(method, path)
      assert_equal(403, response.status, "#{method} #{path} should require CSRF protection")
      assert_equal("CSRF validation failed", response.body)
    end
  end

  def test_mutating_endpoints_reject_cross_site_requests
    message = Logster.store.report(Logger::WARN, "test", "csrf protected")

    response =
      raw_request.put(
        "/logsie/protect/#{message.key}",
        "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
        "HTTP_SEC_FETCH_SITE" => "cross-site",
      )

    assert_equal(403, response.status)
    refute(Logster.store.get(message.key).protected)
  end

  def test_mutating_endpoints_reject_mismatched_origin
    message = Logster.store.report(Logger::WARN, "test", "csrf protected")

    response =
      raw_request.put(
        "/logsie/protect/#{message.key}",
        "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
        "HTTP_SEC_FETCH_SITE" => "same-origin",
        "HTTP_ORIGIN" => "https://attacker.example.com",
      )

    assert_equal(403, response.status)
    refute(Logster.store.get(message.key).protected)
  end

  def test_protect_accepts_same_origin_ajax_and_uses_see_other_redirect
    message = Logster.store.report(Logger::WARN, "test", "protect me")

    response = request.put("/logsie/protect/#{message.key}")

    assert_equal(303, response.status)
    assert_equal("/logsie/show/#{message.key}?protected=true", response.headers["location"])
    assert(Logster.store.get(message.key).protected)
  end

  def test_authorization_callback_guards_logster_routes
    received_env = nil
    Logster.config.authorize_request =
      lambda do |env|
        received_env = env
        false
      end

    response = request.get("/logsie/")

    assert_equal(403, response.status)
    assert_equal("Not authorized", response.body)
    assert_equal("/logsie/", received_env["PATH_INFO"])
  end

  def test_authorization_does_not_intercept_downstream_routes
    Logster.config.authorize_request = ->(_) { false }
    downstream =
      Rack::MockRequest.new(Rack::Lint.new(Logster::Middleware::Viewer.new(BrokenApp.new)))

    response = downstream.get("/not-logster")

    assert_equal(500, response.status)
    assert_equal("broken", response.body)
  end

  def test_logster_responses_have_security_headers
    response = request.get("/logsie/")

    assert_equal("no-store", response.headers["cache-control"])
    assert_equal("nosniff", response.headers["x-content-type-options"])
    assert_equal("DENY", response.headers["x-frame-options"])
    assert_equal("no-referrer", response.headers["referrer-policy"])
    assert_includes(response.headers["content-security-policy"], "default-src 'none'")
    assert_includes(response.headers["content-security-policy"], "frame-ancestors 'none'")
  end

  def test_static_assets_can_be_cached_and_revalidated
    response = request.get("/logsie/images/icon_64x64.png")

    assert_equal(200, response.status)
    assert_equal("public, max-age=0, must-revalidate", response.headers["cache-control"])
    assert_equal("nosniff", response.headers["x-content-type-options"])
  end

  def test_app_html_uses_the_generated_asset_manifest
    manifest = {
      "javascript" => %w[vendor.js chunk.application.js client-app.js],
      "stylesheets" => %w[vendor.css client-app.css],
      "config" => {
        "modulePrefix" => "client-app",
        "environment" => "production",
        "rootURL" => "/logs/",
        "locationType" => "history",
        "EmberENV" => {
          "_USE_EMBER_MODULES" => true,
        },
      },
    }

    viewer.instance_variable_set(:@asset_manifest, manifest)
    response = request.get("/logsie/")
    nonce = response.headers["content-security-policy"][/script-src 'nonce-([^']+)'/, 1]

    assert(nonce)
    manifest["javascript"].each do |name|
      assert_includes(
        response.body,
        "<script src='/logsie/javascript/#{name}' nonce='#{nonce}'></script>",
      )
    end
    assert_operator(
      response.body.index("vendor.js"),
      :<,
      response.body.index("chunk.application.js"),
    )
    assert_operator(
      response.body.index("chunk.application.js"),
      :<,
      response.body.index("client-app.js"),
    )

    encoded_config = response.body[%r{name="client-app/config/environment" content="([^"]+)"}, 1]
    config = JSON.parse(URI.decode_www_form_component(encoded_config))
    assert_equal("/logsie/", config["rootURL"])
    assert_equal(true, config.dig("EmberENV", "_USE_EMBER_MODULES"))
  end

  def test_search_raceguard_s
    response = request.post("/logsie/messages.json?search=searchkey")
    result = JSON.parse(response.body)
    assert_equal("searchkey", result["search"])
  end

  def test_search_raceguard_sr
    response = request.post("/logsie/messages.json?search=/regex/&regex_search=true")
    result = JSON.parse(response.body)
    assert_equal("/regex/", result["search"])
  end

  def test_search_raceguard_f
    response = request.post("/logsie/messages.json?filter=0_1_2_3_4")
    result = JSON.parse(response.body)
    assert_equal([0, 1, 2, 3, 4], result["filter"])
  end

  def test_search_does_not_respond_to_get_requests
    response = request.get("/logsie/messages.json?filter=0_1_2_3_4")
    assert_equal(404, response.status)
    assert_equal("Not found", response.body)
  end

  def test_regex_parse
    assert_equal(/hello/i, viewer.send(:parse_regex, "/hello/i"))
  end

  def test_settings_page_responds_with_json
    Logster.store.ignore = [/somepattern/, /anotherpattern/]
    record = Logster::SuppressionPattern.new("custompattern")
    record.save

    Logster.store.report(Logger::INFO, "test", "somepattern")
    response = request.get("/logsie/settings.json")
    assert_equal(200, response.status)
    assert_includes(response.content_type, "application/json")

    json = JSON.parse(response.body)
    suppression = json["suppression"]
    custom_patterns = suppression.reject { |p| p["hard"] }.map { |p| p["value"] }
    coded_patterns = suppression.select { |p| p["hard"] }.map { |p| p["value"] }
    assert_includes(custom_patterns, "/custompattern/")
    assert_includes(coded_patterns, "/somepattern/")
    assert_includes(coded_patterns, "/anotherpattern/")

    Logster.store.ignore = nil
    record.destroy

    response = request.get("/logsie/settings.json")
    assert_equal(200, response.status)
    json = JSON.parse(response.body)
    assert_equal([], json["suppression"])
  ensure
    Logster.store.ignore = nil
  end

  def test_settings_page_responds_with_html
    response = request.get("/logsie/settings")
    assert_equal(200, response.status)
    assert_includes(response.content_type, "text/html")
  end

  def test_patterns_endpoint_doesnt_accept_GETs
    Logster.config.enable_custom_patterns_via_ui = true

    response =
      request.get("/logsie/patterns/suppression.json", params: { pattern: "patternfromuser" })
    assert_equal(405, response.status)
    assert_equal(0, Logster::SuppressionPattern.find_all.size)
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_patterns_endpoint_doesnt_work_when_its_disabled_from_config
    Logster.config.enable_custom_patterns_via_ui = false

    response =
      request.post("/logsie/patterns/suppression.json", params: { pattern: "patternfromuser" })
    assert_equal(403, response.status)
    assert_equal(0, Logster::SuppressionPattern.find_all.size)
  end

  def test_patterns_endpoint_doesnt_work_with_undefined_set
    Logster.config.enable_custom_patterns_via_ui = true

    response =
      request.post("/logsie/patterns/weirdset.json", params: { pattern: "disallowedpattern" })
    assert_equal(404, response.status)
    Logster::Pattern.child_classes.each { |klass| assert_equal(0, klass.find_all.size) }
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_creating_patterns_works
    Logster.config.enable_custom_patterns_via_ui = true

    response = request.post("/logsie/patterns/suppression.json", params: { pattern: "newpattern" })
    assert_equal(200, response.status)
    assert_equal(/newpattern/, Logster::SuppressionPattern.find_all.first)

    json = JSON.parse(response.body)
    assert_equal("/newpattern/", json["pattern"])
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_suppression_patterns_have_optional_retroactive_effect
    Logster.config.enable_custom_patterns_via_ui = true

    Logster.store.report(Logger::INFO, "test", "non-matching message")
    Logster.store.report(Logger::INFO, "test", "apple orange")
    Logster.store.report(Logger::INFO, "test", "apples oranges")

    request.post("/logsie/patterns/suppression.json", params: { pattern: "apple" })
    messages = Logster.store.latest
    assert_includes(messages.map(&:message), "apple orange")
    assert_includes(messages.map(&:message), "apples oranges")
    assert_includes(messages.map(&:message), "non-matching message")

    request.post(
      "/logsie/patterns/suppression.json",
      params: {
        pattern: "orange",
        retroactive: true,
      },
    )
    messages = Logster.store.latest
    assert_equal(1, messages.size)
    assert_equal("non-matching message", messages.first.message)

    response =
      request.post(
        "/logsie/patterns/suppression.json",
        params: {
          pattern: "doesntmatchanything",
          retroactive: true,
        },
      )
    # assert no error occures if it doesn't delete anything retroactively
    assert_equal(200, response.status)
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_modifying_patterns_returns_404_for_non_existing_patterns
    Logster.config.enable_custom_patterns_via_ui = true

    response =
      request.put(
        "/logsie/patterns/suppression.json",
        params: {
          new_pattern: "doesntexists",
          pattern: "doesntexisttoo",
        },
      )

    assert_equal(404, response.status)
    assert_equal(0, Logster::SuppressionPattern.find_all.size)
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_modifying_doesnt_accept_empty_regexp
    Logster.config.enable_custom_patterns_via_ui = true
    Logster::SuppressionPattern.new("goodcitizen").save

    response =
      request.put(
        "/logsie/patterns/suppression.json",
        params: {
          new_pattern: "",
          pattern: "goodcitizen",
        },
      )

    assert_equal(400, response.status)
    patterns = Logster::SuppressionPattern.find_all
    assert_equal(1, patterns.size)
    assert_equal(/goodcitizen/, patterns.first)
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_modifying_patterns_works
    Logster.config.enable_custom_patterns_via_ui = true
    Logster::SuppressionPattern.new("oldpattern").save
    Logster::SuppressionPattern.new("notgoinganywhere").save

    response =
      request.put(
        "/logsie/patterns/suppression.json",
        params: {
          pattern: "oldpattern",
          new_pattern: "brandnewpattern",
        },
      )

    assert_equal(200, response.status)
    patterns = Logster::SuppressionPattern.find_all
    assert_equal(2, patterns.size)
    assert_includes(patterns, /brandnewpattern/)
    assert_includes(patterns, /notgoinganywhere/)

    json = JSON.parse(response.body)
    assert_equal("/brandnewpattern/", json["pattern"])
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_removing_patterns_works
    Logster.config.enable_custom_patterns_via_ui = true
    Logster::SuppressionPattern.new("tobedeleted").save
    Logster::SuppressionPattern.new("notgoinganywhere").save

    response =
      request.delete("/logsie/patterns/suppression.json", params: { pattern: "tobedeleted" })
    assert_equal(200, response.status)

    response =
      request.delete("/logsie/patterns/suppression.json", params: { pattern: "doesntexistanymore" })
    assert_equal(404, response.status)

    patterns = Logster::SuppressionPattern.find_all
    assert_equal(1, patterns.size)
    assert_includes(patterns, /notgoinganywhere/)
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_created_pattern_can_be_deleted_using_the_canonical_value_returned_to_the_ui
    Logster.config.enable_custom_patterns_via_ui = true

    %w[suppression grouping].each do |set_name|
      create_response =
        request.post("/logsie/patterns/#{set_name}.json", params: { pattern: "aaa" })
      assert_equal(200, create_response.status)
      canonical_pattern = JSON.parse(create_response.body).fetch("pattern")
      assert_equal("/aaa/", canonical_pattern)

      delete_response =
        request.delete("/logsie/patterns/#{set_name}.json", params: { pattern: canonical_pattern })
      assert_equal(200, delete_response.status)

      repeated_delete =
        request.delete("/logsie/patterns/#{set_name}.json", params: { pattern: canonical_pattern })
      assert_equal(404, repeated_delete.status)
    end
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_clear_all_button_shouldnt_clear_custom_patterns
    Logster::SuppressionPattern.new("testpattern").save

    Logster.store.report(Logger::INFO, "test", "mysmalltest")
    Logster.store.report(Logger::INFO, "test", "another test")

    response = request.post("/logsie/clear")

    assert_equal(200, response.status)
    assert_equal(0, Logster.store.latest.size)
    records = Logster::SuppressionPattern.find_all
    assert_equal(1, records.size)
    assert_equal(/testpattern/, records.first)
  end

  def test_reset_ignore_count_works
    Logster.store.ignore = [/whatever store/]
    Logster.store.allow_custom_patterns = true
    Logster::SuppressionPattern.new(/custom pattern/).save

    Logster.store.report(Logger::INFO, "test", "something whatever store")
    Logster.store.report(Logger::INFO, "test", "this is for custom pattern")

    response = request.get("/logsie/settings.json")
    assert_equal(200, response.status)
    json = JSON.parse(response.body)
    suppression = json["suppression"]
    assert_equal("1", suppression.find { |p| p["value"] == "/whatever store/" }["count"])
    assert_equal("1", suppression.find { |p| p["value"] == "/custom pattern/" }["count"])

    response =
      request.put("/logsie/reset-count.json", params: { pattern: "/whatever store/", hard: true })
    assert_equal(200, response.status)

    response =
      request.put("/logsie/reset-count.json", params: { pattern: "/custom pattern/", hard: false })
    assert_equal(200, response.status)

    hash = Logster.store.get_all_ignore_count
    assert_equal({}, hash)
  end

  def test_linking_to_valid_javascript_files
    viewer
      .send(:asset_manifest)
      .fetch("javascript")
      .each do |name|
        response = request.get("/logsie/javascript/#{name}")
        assert_equal(200, response.status)
        assert %w[text/javascript application/javascript].include?(response.headers["content-type"])
      end
  end

  def test_linking_to_valid_stylesheets
    viewer
      .send(:asset_manifest)
      .fetch("stylesheets")
      .each do |name|
        response = request.get("/logsie/stylesheets/#{name}")
        assert_equal(200, response.status)
        assert_equal("text/css", response.headers["content-type"])
      end
  end

  def test_linking_to_an_invalid_ember_component_or_template
    %w[
      /logsie/javascript/templates/application.hbs
      /logsie/javascript/templates/does_not_exist.js
      /logsie/javascript/components/does_not_exist.js
      /logsie/javascript/templates/../../app.js
    ].each do |path|
      response = request.get(path)
      assert_equal(404, response.status, "#{path} should have 404'ed")
    end
  end

  def test_messages_endpoint_doesnt_include_envs_when_search_term_absent
    Logster.store.clear_all
    env = { "b" => 1, "c" => 2 }
    msg = Logster.store.report(Logger::INFO, "test", "something hello", env: env)
    response = request.post("/logsie/messages.json")
    assert_equal(200, response.status)
    messages = JSON.parse(response.body)["messages"]
    assert_equal(1, messages.size)
    msg = messages.first
    assert_equal("something hello", msg["message"])
    assert_nil(msg["env"])
  end

  def test_messages_endpoint_includes_env_when_there_is_search_term
    Logster.store.clear_all
    env = { "b" => 1, "c" => 2 }
    msg = Logster.store.report(Logger::INFO, "test", "something hello", env: env)
    response = request.post("/logsie/messages.json?search=something")
    assert_equal(200, response.status)
    messages = JSON.parse(response.body)["messages"]
    assert_equal(1, messages.size)
    msg = messages.first
    assert_equal("something hello", msg["message"])
    assert_includes(msg["env"].values, 1, 2)
  end

  def test_fetch_env_returns_env_associated_with_message
    env = { "b" => 1, "c" => 2 }
    msg = Logster.store.report(Logger::INFO, "test", "something whatever store", env: env)
    response = request.get("/logsie/fetch-env/#{msg.key}.json")
    assert_equal(200, response.status)
    res = JSON.parse(response.body)
    assert_includes(res.values, 1, 2)
  end

  def test_fetch_env_returns_404_when_invalid_key
    response = request.get("/logsie/fetch-env/123456abc.json")
    assert_equal(404, response.status)
  end

  def test_solve_group_api_requires_post_request
    Logster.config.enable_custom_patterns_via_ui = true
    Logster::GroupingPattern.new(/gotta be post/).save
    msg =
      Logster.store.report(
        Logger::WARN,
        "",
        "gotta be post 22",
        env: {
          "application_version" => "abc",
        },
        backtrace: "aa",
      )
    latest = Logster.store.latest
    assert_equal(1, latest.size)
    assert_equal(msg.key, latest.first["messages"].first.key)
    %i[get head options].each do |m|
      response = request.public_send(m, "/logsie/solve-group", params: { regex: "/gotta be post/" })
      assert_equal(405, response.status)
      assert_equal("POST", response.headers["allow"])
    end
    latest = Logster.store.latest
    assert_equal(1, latest.size)
    assert_equal(msg.key, latest.first["messages"].first.key)
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_solve_group_returns_404_when_pattern_doesnt_exist
    Logster.config.enable_custom_patterns_via_ui = true
    Logster::GroupingPattern.new(/some pattern/).save
    msg =
      Logster.store.report(
        Logger::WARN,
        "",
        "some pattern 22",
        env: {
          "application_version" => "abc",
        },
        backtrace: "aa",
      )
    latest = Logster.store.latest
    assert_equal(1, latest.size)
    assert_equal(msg.key, latest.first["messages"].first.key)
    response = request.post("/logsie/solve-group", params: { regex: "/i dont exist/" })
    assert_equal(404, response.status)
    latest = Logster.store.latest
    assert_equal(1, latest.size)
    assert_equal(msg.key, latest.first["messages"].first.key)
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_solving_grouped_messages
    Logster.config.enable_custom_patterns_via_ui = true
    backtrace = "a b c d"
    Logster::GroupingPattern.new(/test pattern/).save
    msg1 = Logster.store.report(Logger::WARN, "", "test pattern 1", backtrace: backtrace)
    msg2 =
      Logster.store.report(
        Logger::WARN,
        "",
        "test pattern 2",
        env: {
          "application_version" => "abc",
        },
        backtrace: backtrace,
      )
    msg3 =
      Logster.store.report(
        Logger::WARN,
        "",
        "test pattern 3",
        env: [{ "application_version" => "def" }, { "application_version" => "ghi" }],
        backtrace: backtrace,
      )
    group = Logster.store.find_pattern_groups { |p| p == /test pattern/ }.first
    assert_equal([msg3, msg2, msg1].map(&:key), group.messages_keys)

    latest = Logster.store.latest
    assert_equal(1, latest.size)
    assert_equal([msg1, msg2, msg3].map(&:key).sort, latest.first["messages"].map(&:key).sort)

    response = request.post("/logsie/solve-group", params: { regex: "/test pattern/" })
    group = Logster.store.find_pattern_groups { |p| p == /test pattern/ }.first
    assert_equal([msg1.key], group.messages_keys)
    assert_equal(200, response.status)

    latest = Logster.store.latest
    # msg1 remains cause it doesn't have application_version
    assert_equal([msg1.key], latest.first["messages"].map(&:key))
    assert_equal(1, latest.size)

    msg4 = Logster.store.report(Logger::WARN, "", "test pattern 4", backtrace: backtrace)
    %w[abc def ghi].each do |version|
      Logster.store.report(
        Logger::WARN,
        "",
        "test pattern 5",
        env: {
          "application_version" => version,
        },
        backtrace: backtrace,
      )
    end
    latest = Logster.store.latest
    assert_equal([msg1.key, msg4.key].sort, latest.first["messages"].map(&:key).sort)
    assert_equal(1, latest.size)
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end
end

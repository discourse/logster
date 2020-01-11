# frozen_string_literal: true

require_relative '../../test_helper'
require 'rack'
require 'logster/redis_store'
require 'logster/middleware/viewer'

class TestViewer < Minitest::Test

  class BrokenApp
    def call(env)
      [500, {}, ["broken"]]
    end
  end

  def setup
    Logster.config.subdirectory = "/logsie"
    Logster.store = Logster::RedisStore.new
    Logster.store.clear_all
  end

  def teardown
    Logster.config.subdirectory = nil
    Logster.store.clear_all
    Logster.store = nil
  end

  def viewer
    @viewer ||= Logster::Middleware::Viewer.new(nil)
  end

  def request
    @request ||= Rack::MockRequest.new(Rack::Lint.new(viewer))
  end

  def test_path_resolution
    assert_nil(viewer.send(:resolve_path, "/logs"))
    assert_nil(viewer.send(:resolve_path, "/admin/logsie"))
    assert_nil(viewer.send(:resolve_path, "/admin/logsie/bla"))
    assert_equal("/", viewer.send(:resolve_path, "/logsie"))
    assert_equal("/", viewer.send(:resolve_path, "/logsie/"))
    assert_equal("/hello/world", viewer.send(:resolve_path, "/logsie/hello/world"))
  end

  def test_search_raceguard_s
    response = request.get('/logsie/messages.json?search=searchkey')
    result = JSON.parse(response.body)
    assert_equal('searchkey', result['search'])
  end

  def test_search_raceguard_sr
    response = request.get('/logsie/messages.json?search=/regex/&regex_search=true')
    result = JSON.parse(response.body)
    assert_equal('/regex/', result['search'])
  end

  def test_search_raceguard_f
    response = request.get("/logsie/messages.json?filter=0_1_2_3_4")
    result = JSON.parse(response.body)
    assert_equal([0, 1, 2, 3, 4], result['filter'])
  end

  def test_regex_parse
    assert_equal(/hello/i, viewer.send(:parse_regex, '/hello/i'))
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

    response = request.get("/logsie/patterns/suppression.json",
      params: { pattern: "patternfromuser" }
    )
    assert_equal(405, response.status)
    assert_equal(0, Logster::SuppressionPattern.find_all.size)
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_patterns_endpoint_doesnt_work_when_its_disabled_from_config
    Logster.config.enable_custom_patterns_via_ui = false

    response = request.post("/logsie/patterns/suppression.json",
      params: { pattern: "patternfromuser" }
    )
    assert_equal(403, response.status)
    assert_equal(0, Logster::SuppressionPattern.find_all.size)
  end

  def test_patterns_endpoint_doesnt_work_with_undefined_set
    Logster.config.enable_custom_patterns_via_ui = true

    response = request.post("/logsie/patterns/weirdset.json",
      params: { pattern: "disallowedpattern" }
    )
    assert_equal(404, response.status)
    Logster::Pattern.child_classes.each do |klass|
      assert_equal(0, klass.find_all.size)
    end
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_creating_patterns_works
    Logster.config.enable_custom_patterns_via_ui = true

    response = request.post("/logsie/patterns/suppression.json",
      params: { pattern: "newpattern" }
    )
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

    request.post("/logsie/patterns/suppression.json",
      params: { pattern: "apple" }
    )
    messages = Logster.store.latest
    assert_includes(messages.map(&:message), "apple orange")
    assert_includes(messages.map(&:message), "apples oranges")
    assert_includes(messages.map(&:message), "non-matching message")

    request.post("/logsie/patterns/suppression.json",
      params: { pattern: "orange", retroactive: true }
    )
    messages = Logster.store.latest
    assert_equal(1, messages.size)
    assert_equal("non-matching message", messages.first.message)

    response = request.post("/logsie/patterns/suppression.json",
      params: { pattern: "doesntmatchanything", retroactive: true }
    )
    # assert no error occures if it doesn't delete anything retroactively
    assert_equal(200, response.status)
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_modifying_patterns_returns_404_for_non_existing_patterns
    Logster.config.enable_custom_patterns_via_ui = true

    response = request.put("/logsie/patterns/suppression.json",
      params: { new_pattern: "doesntexists", pattern: "doesntexisttoo" }
    )

    assert_equal(404, response.status)
    assert_equal(0, Logster::SuppressionPattern.find_all.size)
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_modifying_doesnt_accept_empty_regexp
    Logster.config.enable_custom_patterns_via_ui = true
    Logster::SuppressionPattern.new("goodcitizen").save

    response = request.put("/logsie/patterns/suppression.json",
      params: { new_pattern: "", pattern: "goodcitizen" }
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

    response = request.put("/logsie/patterns/suppression.json",
      params: { pattern: "oldpattern", new_pattern: "brandnewpattern" }
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

    response = request.delete("/logsie/patterns/suppression.json",
      params: { pattern: "tobedeleted" }
    )
    assert_equal(200, response.status)

    response = request.delete("/logsie/patterns/suppression.json",
      params: { pattern: "doesntexistanymore" }
    )
    assert_equal(404, response.status)

    patterns = Logster::SuppressionPattern.find_all
    assert_equal(1, patterns.size)
    assert_includes(patterns, /notgoinganywhere/)
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

    response = request.put("/logsie/reset-count.json",
      params: { pattern: "/whatever store/", hard: true }
    )
    assert_equal(200, response.status)

    response = request.put("/logsie/reset-count.json",
      params: { pattern: "/custom pattern/", hard: false }
    )
    assert_equal(200, response.status)

    hash = Logster.store.get_all_ignore_count
    assert_equal({}, hash)
  end

  def test_linking_to_a_valid_js_files
    %w(
      /logsie/javascript/client-app.js
      /logsie/javascript/vendor.js
    ).each do |path|
      response = request.get(path)
      assert_equal(200, response.status)
      assert_equal('application/javascript', response.headers['Content-Type'])
    end
  end

  def test_linking_to_a_valid_css_files
    %w(
      /logsie/stylesheets/client-app.css
      /logsie/stylesheets/vendor.css
    ).each do |path|
      response = request.get(path)
      assert_equal(200, response.status)
      assert_equal('text/css', response.headers['Content-Type'])
    end
  end

  def test_linking_to_an_invalid_ember_component_or_template
    %w(
      /logsie/javascript/templates/application.hbs
      /logsie/javascript/templates/does_not_exist.js
      /logsie/javascript/components/does_not_exist.js
      /logsie/javascript/templates/../../app.js
    ).each do |path|
      response = request.get(path)
      assert_equal(404, response.status, "#{path} should have 404'ed")
    end
  end

  def test_messages_endpoint_doesnt_include_envs_when_search_term_absent
    Logster.store.clear_all
    env = { "b" => 1, "c" => 2 }
    msg = Logster.store.report(Logger::INFO, "test", "something hello", env: env)
    response = request.get("/logsie/messages.json")
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
    response = request.get("/logsie/messages.json?search=something")
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
    msg = Logster.store.report(
      Logger::WARN,
      '',
      'gotta be post 22',
      env: { "application_version" => "abc" },
      backtrace: "aa"
    )
    latest = Logster.store.latest
    assert_equal(1, latest.size)
    assert_equal(msg.key, latest.first["messages"].first.key)
    %i[get head options].each do |m|
      response = request.public_send(m, "/logsie/solve-group", params: { regex: "/gotta be post/" })
      assert_equal(405, response.status)
      assert_equal("POST", response.headers["Allow"])
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
    msg = Logster.store.report(
      Logger::WARN,
      '',
      'some pattern 22',
      env: { "application_version" => "abc" },
      backtrace: "aa"
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
    msg1 = Logster.store.report(Logger::WARN, '', 'test pattern 1', backtrace: backtrace)
    msg2 = Logster.store.report(
      Logger::WARN,
      '',
      'test pattern 2',
      env: { "application_version" => "abc" },
      backtrace: backtrace
    )
    msg3 = Logster.store.report(
      Logger::WARN,
      '',
      'test pattern 3',
      env: [{ "application_version" => "def" }, { "application_version" => "ghi" }],
      backtrace: backtrace
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

    msg4 = Logster.store.report(Logger::WARN, '', 'test pattern 4', backtrace: backtrace)
    %w[abc def ghi].each do |version|
      Logster.store.report(
        Logger::WARN,
        '',
        'test pattern 5',
        env: { "application_version" => version },
        backtrace: backtrace
      )
    end
    latest = Logster.store.latest
    assert_equal([msg1.key, msg4.key].sort, latest.first["messages"].map(&:key).sort)
    assert_equal(1, latest.size)
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end
end

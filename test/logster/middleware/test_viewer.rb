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
    Logster::PATTERNS.each do |klass|
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
end

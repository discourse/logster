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
  end

  def teardown
    Logster.config.subdirectory = nil
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
    assert_equal("/",viewer.send(:resolve_path, "/logsie"))
    assert_equal("/",viewer.send(:resolve_path, "/logsie/"))
    assert_equal("/hello/world",viewer.send(:resolve_path, "/logsie/hello/world"))
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
    assert_equal([0,1,2,3,4], result['filter'])
  end

  def test_assets
    response = request.get('/logsie/javascript/external/jquery.min.js')
    assert_equal(200, response.status)
  end

  def test_regex_parse
    assert_equal(/hello/i, viewer.send(:parse_regex, '/hello/i'))
  end

  def test_linking_to_a_valid_ember_component
    response = request.get('/logsie/javascript/components/message-row.js')

    assert_equal(200, response.status)
    assert_equal('application/javascript', response.headers['Content-Type'])
    assert_match(/Ember.TEMPLATES\["components\/message-row"\]/, response.body)
  end

  def test_linking_to_a_valid_ember_template
    response = request.get('/logsie/javascript/templates/application.js')

    assert_equal(200, response.status)
    assert_equal('application/javascript', response.headers['Content-Type'])
    assert_match(/Ember.TEMPLATES\["application"\]/, response.body)
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

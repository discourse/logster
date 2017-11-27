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
    Logster.store = Logster::RedisStore.new
  end

  def teardown
    Logster.config.subdirectory = nil
    Logster.store = nil
  end

  def viewer
    @viewer ||= begin
                  Logster.config.subdirectory = "/logsie"
                  Logster::Middleware::Viewer.new(nil)
                end
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
    _,_,result_j = viewer.call(Rack::MockRequest.env_for("/logsie/messages.json?search=searchkey"))
    result = JSON.parse(result_j.first)
    assert_equal('searchkey', result['search'])
  end

  def test_search_raceguard_sr
    _,_,result_j = viewer.call(Rack::MockRequest.env_for("/logsie/messages.json?search=/regex/&regex_search=true"))
    result = JSON.parse(result_j.first)
    assert_equal('/regex/', result['search'])
  end

  def test_search_raceguard_f
    _,_,result_j = viewer.call(Rack::MockRequest.env_for("/logsie/messages.json?filter=0_1_2_3_4"))
    result = JSON.parse(result_j.first)
    assert_equal([0,1,2,3,4], result['filter'])
  end

  def test_assets
    env = {}
    env["PATH_INFO"] = "/logsie/javascript/external/jquery.min.js"
    env["REQUEST_METHOD"] = "GET"

    result,  = viewer.call(env)
    assert_equal(200, result)
  end

  def test_regex_parse
    assert_equal(/hello/i, viewer.send(:parse_regex, '/hello/i'))
  end

end

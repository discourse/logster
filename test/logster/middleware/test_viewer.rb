require 'test_helper'
require 'rack'
require 'logster/redis_store'
require 'logster/middleware/viewer'

class TestViewer < Minitest::Test

  def teardown
  end

  def viewer
    @viewer ||= begin
                  store = Logster::RedisStore.new
                  Logster::Middleware::Viewer.new(nil, store: store, path: "/logsie")
                end
  end

  def test_path_resolution
    assert_nil(viewer.send(:resolve_path, "/logs"))
    assert_equal("/",viewer.send(:resolve_path, "/logsie"))
    assert_equal("/",viewer.send(:resolve_path, "/logsie/"))
    assert_equal("/hello/world",viewer.send(:resolve_path, "/logsie/hello/world"))
  end

  def test_assets
    env = {}
    env["PATH_INFO"] = "/logsie/javascript/external/jquery.min.js"
    env["REQUEST_METHOD"] = "GET"

    result,  = viewer.call(env)
    assert_equal(200, result)
  end

end

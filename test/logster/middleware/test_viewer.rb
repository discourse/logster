require 'test_helper'
require 'rack'
require 'logster/middleware/viewer'

class TestViewer < Minitest::Test
  def test_path_resolution
    viewer = Logster::Middleware::Viewer.new(nil, path: "/logsie")

    assert_nil(viewer.send(:resolve_path, "/logs"))
    assert_equal("/",viewer.send(:resolve_path, "/logsie"))
    assert_equal("/",viewer.send(:resolve_path, "/logsie/"))
    assert_equal("/hello/world",viewer.send(:resolve_path, "/logsie/hello/world"))
  end

  def test_assets
    viewer = Logster::Middleware::Viewer.new(nil, path: "/logsie")

    env = {}
    env["PATH_INFO"] = "/logsie/javascript/external/jquery.min.js"
    env["REQUEST_METHOD"] = "GET"

    result,  = viewer.call(env)
    assert_equal(200, result)

  end
end

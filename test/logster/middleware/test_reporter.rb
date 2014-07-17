require_relative '../../test_helper'
require 'rack'
require 'logster/redis_store'
require 'logster/middleware/reporter'


class TestReporter < Minitest::Test

  def test_logs_errors
    Logster.store = Logster::TestStore.new

    reporter = Logster::Middleware::Reporter.new(nil)
    env = Rack::MockRequest.env_for("/logs/report_js_error?message=hello")
    status, = reporter.call(env)

    assert_equal(200, status)
    assert_equal(1, Logster.store.count)
  end

end


# frozen_string_literal: true

require_relative '../../test_helper'
require 'rack'
require 'logster/redis_store'
require 'logster/middleware/reporter'

class TestReporter < Minitest::Test

  def setup
    Logster.store = Logster::RedisStore.new
    Logster.store.clear_all
    Logster.config.enable_js_error_reporting = true
    Logster.config.rate_limit_error_reporting = true
  end

  def test_logs_errors
    reporter = Logster::Middleware::Reporter.new(nil)
    env = Rack::MockRequest.env_for("/logs/report_js_error?message=hello")
    status, = reporter.call(env)

    assert_equal(200, status)
    assert_equal(1, Logster.store.count)
  end

  def test_logs_severity_of_errors
    Logster.config.rate_limit_error_reporting = false

    reporter = Logster::Middleware::Reporter.new(nil)
    env = Rack::MockRequest.env_for("/logs/report_js_error?message=hello")
    reporter.call(env)

    assert_equal(Logger::Severity::WARN, Logster.store.latest[-1].severity)

    reporter = Logster::Middleware::Reporter.new(nil)
    env = Rack::MockRequest.env_for("/logs/report_js_error?message=hello&severity=invalid")
    reporter.call(env)

    assert_equal(Logger::Severity::WARN, Logster.store.latest[-1].severity)

    reporter = Logster::Middleware::Reporter.new(nil)
    env = Rack::MockRequest.env_for("/logs/report_js_error?message=hello&severity=error")
    reporter.call(env)

    assert_equal(Logger::Severity::ERROR, Logster.store.latest[-1].severity)
  end

  def test_respects_ban_on_errors
    Logster.config.enable_js_error_reporting = false

    reporter = Logster::Middleware::Reporter.new(nil)
    env = Rack::MockRequest.env_for("/logs/report_js_error?message=hello")
    status, = reporter.call(env)

    assert_equal(403, status)
    assert_equal(0, Logster.store.count)
  end

  def test_rate_limiting
    reporter = Logster::Middleware::Reporter.new(nil)
    env = Rack::MockRequest.env_for("/logs/report_js_error?message=hello")
    status, = reporter.call(env)

    assert_equal(200, status)
    assert_equal(1, Logster.store.count)

    reporter = Logster::Middleware::Reporter.new(nil)
    env = Rack::MockRequest.env_for("/logs/report_js_error?message=hello2")
    status, = reporter.call(env)

    assert_equal(429, status)
    assert_equal(1, Logster.store.count)

    reporter = Logster::Middleware::Reporter.new(nil)
    env = Rack::MockRequest.env_for("/logs/report_js_error?message=hello2", "REMOTE_ADDR" => "100.1.1.2")
    status, = reporter.call(env)

    assert_equal(200, status)
    assert_equal(2, Logster.store.count)
  end

end

require_relative '../test_helper'
require 'logster/logger'
require 'logster/redis_store'
require 'logger'
require 'examples/sidekiq_logster_reporter'

class TestSidekiqReporter < MiniTest::Test

  def setup
    Logster.store = @store = Logster::RedisStore.new(Redis.new)
    Logster.logger = @logger = Logster::Logger.new(Logster.store)
    @store.clear_all
  end

  def teardown
    @store.clear_all
  end

  def test_sidekiq_handler_example
    handler = SidekiqLogsterReporter.new
    error = nil
    begin
      raise TypeError.new
    rescue => e
      error = e
    end
    trace = error.backtrace

    handler.call(error, code: "Test", something_important: "Foo", params: { article_id: 20 })

    report = @store.latest[0]

    assert_equal("Job exception: TypeError\n", report.message)

    assert_equal(trace.join("\n"), report.backtrace)
    assert_nil(report.env['backtrace'])
    assert_nil(report.env[:backtrace])

    assert_equal("Test", report.env['code'])
    assert_equal(20, report.env['params']['article_id'])
  end
end

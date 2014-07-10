require_relative '../test_helper'
require 'logster/logger'
require 'logger'
require 'examples/sidekiq_logster_reporter'

class TestSidekiqReporter < MiniTest::Test

  def setup
    Logster.store = @store = Logster::TestStore.new
    Logster.logger = @logger = Logster::Logger.new(Logster.store)
  end

  def test_sidekiq_handler_example
    handler = SidekiqLogsterReporter.new
    error = nil
    begin
      raise TypeError.new
    rescue => e
      error = e
    end

    handler.call(error, code: "Test", something_important: "Foo", params: { article_id: 20 })

    error = Logster.store.reported[0]

    assert(error.backtrace != nil)
    assert_equal("Job exception: TypeError\n", error.message)
    assert_equal("Test", error.env[:code])
    assert_equal(20, error.env[:params][:article_id])
  end
end

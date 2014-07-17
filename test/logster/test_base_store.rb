require_relative '../test_helper'
require 'logster/base_store'

class TestBaseStore < Minitest::Test

  def setup
    @store = Logster::TestStore.new
    @store.clear_all
  end

  def teardown
    @store.clear_all
  end

  def test_report_skip_empty
    @store.skip_empty = true
    @store.report(Logger::WARN, "test", nil)
    @store.report(Logger::WARN, "test", '')
    @store.report(Logger::WARN, "test", "foo") #
    @store.skip_empty = false
    @store.report(Logger::WARN, "test", nil) #

    assert_equal(2, @store.count)
  end

  def test_report_skip_level
    @store.level = nil
    @store.report(Logger::DEBUG, "test", "A") #
    @store.level = Logger::WARN
    @store.report(Logger::DEBUG, "test", "A")
    @store.report(Logger::INFO, "test", "B")
    @store.report(Logger::WARN, "test", "C") #
    @store.report(Logger::ERROR, "test", "D") #
    assert_equal(3, @store.count)
  end

  def test_report_skip_ignore
    @store.report(Logger::WARN, "test", "Can't verify CSRF token authenticity")
    @store.report(Logger::FATAL, "test", "ActiveRecord::RecordNotFound (Couldn't find Upload with 'id'=9947)")
    @store.report(Logger::WARN, "test", "B")
    @store.ignore = [
        /^ActiveRecord::RecordNotFound \(Couldn't find Upload/,
        /^Can't verify CSRF token authenticity/
    ]
    @store.report(Logger::WARN, "test", "Can't verify CSRF token authenticity")
    @store.report(Logger::FATAL, "test", "ActiveRecord::RecordNotFound (Couldn't find Upload with 'id'=9947)")
    @store.report(Logger::FATAL, "test", "ActiveRecord::RecordNotFound (Couldn't find Upload with 'id'=9489+78946947)")
    @store.report(Logger::WARN, "test", "B")

    assert_equal(4, @store.count)
  end

  def test_timestamp
    time = Time.now - 24*60*60
    message = @store.report(Logger::WARN, "test", "B", timestamp: time)

    assert_equal(time, message.timestamp)
  end

  def test_backtrace
    # Create an error with a backtrace
    error = TypeError.new
    begin
      raise error
    rescue => e
      error = e
    end

    # Backtrace can be passed via backtrace param or env
    message = @store.report(Logger::WARN, "test", "A", backtrace: error.backtrace)
    assert_equal(error.backtrace.join("\n"), message.backtrace)
    message = @store.report(Logger::WARN, "test", "B", env: {backtrace: error.backtrace})
    assert_equal(error.backtrace.join("\n"), message.backtrace)

    # Via env takes priority
    message = @store.report(Logger::WARN, "test", "C", backtrace: "Garbage", env: {backtrace: error.backtrace})
    assert_equal(error.backtrace.join("\n"), message.backtrace)

    # Backtrace is always a string
    # Cannot do an equal assert here, because it uses `caller` when not provided
    message = @store.report(Logger::WARN, "test", "D", backtrace: nil)
    assert_kind_of(String, message.backtrace)
    message = @store.report(Logger::WARN, "test", "E", env: {backtrace: nil})
    assert_kind_of(String, message.backtrace)
    message = @store.report(Logger::WARN, "test", "F", backtrace: nil, env: {backtrace: nil})
    assert_kind_of(String, message.backtrace)
    message = @store.report(Logger::WARN, "test", "G")
    assert_kind_of(String, message.backtrace)

    # Arrays are turned into strings via join \n
    message = @store.report(Logger::WARN, "test", "H", backtrace: ["Foo", "Bar"])
    assert_equal("Foo\nBar", message.backtrace)
  end
end

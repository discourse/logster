require 'test_helper'
require 'logster/redis_store'

class TestRedisStore < Minitest::Test

  def setup
    @store = Logster::RedisStore.new(Redis.new)
  end

  def teardown
    @store.clear
  end

  def test_latest
    @store.report(Logger::WARN, "test", "IGNORE")
    @store.report(Logger::WARN, "test", "This is a warning")
    @store.report(Logger::WARN, "test", "This is another warning")

    latest = @store.latest(limit: 2)

    assert_equal(2, latest.length)
    assert_equal("This is a warning", latest[0].message)
    assert_equal("This is another warning", latest[1].message)
    assert_equal(Logger::WARN, latest[1].severity)
    assert_equal("test", latest[1].progname)
    assert(!latest[1].key.nil?)
  end

  def test_backlog
    @store.max_backlog = 1
    @store.report(Logger::WARN, "test", "A")
    @store.report(Logger::WARN, "test", "B")

    latest = @store.latest

    assert_equal(1, latest.length)
    assert_equal("B", latest[0].message)
  end

  def test_filter_latest
    @store.report(Logger::INFO, "test", "A")
    @store.report(Logger::WARN, "test", "B")
    @store.report(Logger::ERROR, "test", "C")

    latest = @store.latest(severity: [Logger::ERROR, Logger::WARN])

    assert_equal(2, latest.length)
    assert_equal("B", latest[0].message)
    assert_equal("C", latest[1].message)
  end

end

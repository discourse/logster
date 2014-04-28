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
    @store.report(Logger::WARN, "test", "This is a warning")
    @store.report(Logger::WARN, "test", "This is another warning")

    latest = @store.latest

    assert_equal(2, latest.length)
    assert_equal("This is a warning", latest[0].message)
    assert_equal("This is another warning", latest[1].message)
    assert_equal(Logger::WARN, latest[1].severity)
    assert_equal("test", latest[1].progname)
  end

end

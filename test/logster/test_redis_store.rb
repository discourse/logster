require 'test_helper'
require 'logster/redis_store'

class TestRedisStore < Minitest::Test

  def setup
    @store = RedisStore.new(Redis.new)
  end

  def teardown
    @store.clear
  end

  def test_latest
    @store.report(Logger::WARN, "test", "This is a warning")
    @store.report(Logger::WARN, "test", "This is a warning")

    latest = @store.latest

    assert_equal(2, latest.length)
  end

end

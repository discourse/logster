require_relative '../test_helper'
require 'logster/redis_store'
require 'rack'

class TestRedisRateLimiter < Minitest::Test
  def setup
    @redis = Redis.new
  end

  def teardown
    @redis.flushall
    Timecop.return
  end

  def test_clear_all
    called = 0

    @redis.set("dont_nuke", "1")

    @rate_limiter = Logster::RedisRateLimiter.new(
      @redis, [Logger::WARN], 8, 60, Proc.new { "prefix" }, Proc.new { called += 1 }
    )

    9.times do
      @rate_limiter.check(Logger::WARN)
    end

    assert_equal 10, @rate_limiter.check(Logger::WARN)

    Logster::RedisRateLimiter.clear_all(@redis, Proc.new { "prefix" })

    assert_equal 1, @rate_limiter.check(Logger::WARN)

    # also clears when prefix missing
    Logster::RedisRateLimiter.clear_all(@redis)

    assert_equal 1, @rate_limiter.check(Logger::WARN)

    assert_equal "1", @redis.get("dont_nuke")
    @redis.del("dont_nuke")

  end

  def test_check
    time = Time.new(2015, 1, 1, 1, 1)
    Timecop.freeze(time)
    called = 0

    @rate_limiter = Logster::RedisRateLimiter.new(
      @redis, [Logger::WARN], 8, 60, nil, Proc.new { called += 1 }
    )

    assert_equal(1, @rate_limiter.check(Logger::WARN))
    assert_redis_key(60, 0)
    assert_equal(1, number_of_buckets)

    Timecop.freeze(time + 10) do
      assert_equal(2, @rate_limiter.check(Logger::WARN))
      assert_redis_key(60, 1)
      assert_equal(3, @rate_limiter.check(Logger::WARN))
      assert_equal(2, number_of_buckets)
    end

    Timecop.freeze(time + 20) do
      assert_equal(4, @rate_limiter.check(Logger::WARN))
      assert_redis_key(60, 2)
      assert_equal(3, number_of_buckets)
    end

    Timecop.freeze(time + 30) do
      assert_equal(5, @rate_limiter.check(Logger::WARN))
      assert_redis_key(60, 3)
      assert_equal(4, number_of_buckets)
    end

    Timecop.freeze(time + 40) do
      assert_equal(6, @rate_limiter.check(Logger::WARN))
      assert_redis_key(60, 4)
      assert_equal(5, number_of_buckets)
    end

    Timecop.freeze(time + 50) do
      assert_equal(7, @rate_limiter.check(Logger::WARN))
      assert_redis_key(60, 5)
      assert_equal(6, number_of_buckets)
    end

    Timecop.freeze(time + 60) do
      @redis.del("#{key}:0")
      assert_equal(5, number_of_buckets)

      assert_equal(7, @rate_limiter.check(Logger::WARN))
      assert_redis_key(60, 0)
      assert_equal(6, number_of_buckets)

      assert_equal(8, @rate_limiter.check(Logger::WARN))
      assert_equal(1, called)
      assert_equal(6, number_of_buckets)
      assert_equal("1", @redis.get(@rate_limiter.callback_key))
    end

    Timecop.freeze(time + 70) do
      @redis.del("#{key}:1")
      assert_equal(7, @rate_limiter.check(Logger::WARN))
      assert_equal(nil, @redis.get(@rate_limiter.callback_key))
    end
  end

  def test_check_with_multiple_severities
    time = Time.new(2015, 1, 1, 1, 1)
    Timecop.freeze(time)
    called = 0

    @rate_limiter = Logster::RedisRateLimiter.new(
      @redis, [Logger::WARN, Logger::ERROR], 4, 60, nil, Proc.new { called += 1 }
    )

    assert_equal(1, @rate_limiter.check(Logger::WARN))
    assert_equal(2, @rate_limiter.check(Logger::ERROR))

    Timecop.freeze(time + 50) do
      assert_equal(3, @rate_limiter.check(Logger::WARN))
      assert_equal(4, @rate_limiter.check(Logger::ERROR))
      assert_equal(2, number_of_buckets)
    end

    assert_equal(5, @rate_limiter.check(Logger::ERROR))
    assert_equal(1, called)
  end

  def test_bucket_number_per_minute
    time = Time.new(2015, 1, 1, 1, 1)
    Timecop.freeze(time)
    @rate_limiter = Logster::RedisRateLimiter.new(@redis, [Logger::WARN], 1, 60)

    assert_bucket_number(0, time)
    assert_bucket_number(0, time + 9)
    assert_bucket_number(1, time + 11)
    assert_bucket_number(5, time + 59)
  end

  def test_bucket_number_per_hour
    time = Time.new(2015, 1, 1, 1, 0)
    Timecop.freeze(time)
    @rate_limiter = Logster::RedisRateLimiter.new(@redis, [Logger::WARN], 1, 3600)

    assert_bucket_number(0, time)
    assert_bucket_number(1, time + 1199)
    assert_bucket_number(2, time + 1200)
    assert_bucket_number(5, time + 3599)
  end

  def test_bucket_expiry
    time = Time.new(2015, 1, 1, 1, 1)
    Timecop.freeze(time)
    @rate_limiter = Logster::RedisRateLimiter.new(@redis, [Logger::WARN], 1, 60)

    assert_bucket_expiry(60, time)
    assert_bucket_expiry(55, time + 5)
    assert_bucket_expiry(60, time + 10)
    assert_bucket_expiry(58, time + 12)
    assert_bucket_expiry(55, time + 15)
    assert_bucket_expiry(51, time + 19)
    assert_bucket_expiry(60, time + 20)
    assert_bucket_expiry(55, time + 35)
  end

  def test_raw_connection
    time = Time.new(2015, 1, 1, 1, 1)
    Timecop.freeze(time)
    @rate_limiter = Logster::RedisRateLimiter.new(@redis, [Logger::WARN], 1, 60, Proc.new { "lobster" })

    assert_equal(1, @rate_limiter.check(Logger::WARN))
    assert_redis_key(60, 0)

    toggle = true

    @rate_limiter = Logster::RedisRateLimiter.new(
      @redis, [Logger::WARN], 1, 60, Proc.new { toggle ? 'lobster1' : 'lobster2' }
    )

    assert_includes(key, "lobster1")

    toggle = false
    assert_includes(key, "lobster2")
  end

  def test_retrieve_rate
    time = Time.new(2015, 1, 1, 1 , 1)
    Timecop.freeze(time)

    @rate_limiter = Logster::RedisRateLimiter.new(@redis, [Logger::WARN], 1, 60)

    @rate_limiter.check(Logger::WARN)
    assert_equal(@rate_limiter.retrieve_rate, 1)

    Timecop.freeze(time + 50) do
      @rate_limiter.check(Logger::WARN)
      assert_equal(@rate_limiter.retrieve_rate, 2)
    end
  end

  private

  def key
    @rate_limiter.key
  end

  def number_of_buckets
    @redis.keys("#{key}:[0-#{Logster::RedisRateLimiter::BUCKETS}]").size
  end

  def assert_bucket_number(expected, time)
    Timecop.freeze(time) do
      assert_equal(expected, @rate_limiter.send(:bucket_number, Time.now.to_i))
    end
  end

  def assert_bucket_expiry(expected, time)
    Timecop.freeze(time) do
      assert_equal(expected, @rate_limiter.send(:bucket_expiry, Time.now.to_i))
    end
  end

  def assert_redis_key(expected_ttl, expected_bucket_number)
    redis_key = "#{key}:#{expected_bucket_number}"
    assert(@redis.get(redis_key), "the right bucket should be created")
    assert_equal(expected_ttl, @redis.ttl(redis_key))
  end
end

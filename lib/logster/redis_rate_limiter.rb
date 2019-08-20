# frozen_string_literal: true

module Logster
  class RedisRateLimiter
    BUCKETS = 6
    PREFIX = "__LOGSTER__RATE_LIMIT".freeze

    attr_reader :duration, :callback

    def self.clear_all(redis, redis_prefix = nil)
      prefix = key_prefix(redis_prefix)

      redis.eval "
      local keys = redis.call('keys', '*#{prefix}*')
      if (table.getn(keys) > 0) then
        redis.call('del', unpack(keys))
      end
      "
    end

    def initialize(redis, severities, limit, duration, redis_prefix = nil, callback = nil)
      @severities = severities
      @limit = limit
      @duration = duration
      @callback = callback
      @redis_prefix = redis_prefix
      @redis = redis
      @bucket_range = @duration / BUCKETS
      @mget_keys = (0..(BUCKETS - 1)).map { |i| "#{key}:#{i}" }
    end

    def retrieve_rate
      @redis.mget(@mget_keys).reduce(0) { |sum, value| sum + value.to_i }
    end

    def check(severity)
      return unless @severities.include?(severity)
      time = Time.now.to_i
      num = bucket_number(time)
      redis_key = "#{key}:#{num}"

      current_rate = @redis.eval <<-LUA
        local bucket_number = #{num}
        local bucket_count = redis.call("INCR", "#{redis_key}")

        if bucket_count == 1 then
          redis.call("EXPIRE", "#{redis_key}", "#{bucket_expiry(time)}")
          redis.call("DEL", "#{callback_key}")
        end

        local function retrieve_rate ()
          local sum = 0
          local values = redis.call("MGET", #{mget_keys(num)})
          for index, value in ipairs(values) do
            if value ~= false then sum = sum + value end
          end
          return sum
        end

        return (retrieve_rate() + bucket_count)
      LUA

      if !@redis.get(callback_key) && (current_rate >= @limit)
        @callback.call(current_rate) if @callback
        @redis.set(callback_key, 1)
      end

      current_rate
    end

    def key
      # "_LOGSTER_RATE_LIMIT:012:20:30"
      # Triggers callback when log levels of :debug, :info and :warn occurs 20 times within 30 secs
      "#{key_prefix}:#{@severities.join("")}:#{@limit}:#{@duration}"
    end

    def callback_key
      "#{key}:callback_triggered"
    end

    private

    def self.key_prefix(redis_prefix)
      if redis_prefix
        "#{redis_prefix.call}:#{PREFIX}"
      else
        PREFIX
      end

    end

    def key_prefix
      self.class.key_prefix(@redis_prefix)
    end

    def mget_keys(bucket_num)
      keys = @mget_keys.dup
      keys.delete_at(bucket_num)
      keys.map { |key| "'#{key}'" }.join(', ')
    end

    def bucket_number(time)
      (time % @duration) / @bucket_range
    end

    def bucket_expiry(time)
      @duration - ((time % @duration) % @bucket_range)
    end
  end
end

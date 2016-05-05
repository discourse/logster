require 'json'
require 'logster/base_store'

module Logster
  class RedisRateLimiter
    BUCKETS = 6
    PREFIX = "__LOGSTER__RATE_LIMIT".freeze

    attr_reader :duration, :callback

    def self.clear_all(redis, redis_prefix=nil)
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
      "#{@key}:callback_triggered"
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

  class RedisStore < BaseStore

    attr_accessor :redis, :max_backlog, :redis_raw_connection
    attr_writer :redis_prefix

    def initialize(redis = nil)
      super()
      @redis = redis || Redis.new
      @max_backlog = 1000
    end


    def save(message)
      if keys=message.solved_keys
        keys.each do |solved|
          return true if @redis.hget(solved_key, solved)
        end
      end

      @redis.multi do
        @redis.hset(grouping_key, message.grouping_key, message.key)
        @redis.rpush(list_key, message.key)
        update_message(message)
      end

      trim
      check_rate_limits(message.severity)

      true
    end

    def delete(msg)
      @redis.multi do
        @redis.hdel(hash_key, msg.key)
        @redis.hdel(grouping_key, msg.grouping_key)
        @redis.lrem(list_key, -1, msg.key)
      end
    end

    def replace_and_bump(message)
      # TODO make it atomic
      exists = @redis.hexists(hash_key, message.key)
      return false unless exists

      @redis.multi do
        @redis.hset(hash_key, message.key, message.to_json)
        @redis.lrem(list_key, -1, message.key)
        @redis.rpush(list_key, message.key)
      end

      check_rate_limits(message.severity)

      true
    end

    def similar_key(message)
      @redis.hget(grouping_key, message.grouping_key)
    end

    def count
      @redis.llen(list_key)
    end

    def solve(message_key)
      if (message = get(message_key)) && (keys = message.solved_keys)
        # add a time so we can expire it
        keys.each do |s_key|
          @redis.hset(solved_key, s_key, Time.now.to_f.to_i)
        end
      end
      clear_solved
    end

    def latest(opts={})
      limit = opts[:limit] || 50
      severity = opts[:severity]
      before = opts[:before]
      after = opts[:after]
      search = opts[:search]

      start, finish = find_location(before, after, limit)

      return [] unless start && finish

      results = []

      direction = after ? 1 : -1

      begin
        keys = @redis.lrange(list_key, start, finish) || []
        break unless keys and keys.count > 0
        rows = @redis.hmget(hash_key, keys)

        temp = []

        rows.each do |s|
          row = Message.from_json(s)
          break if before && before == row.key
          row = nil if severity && !severity.include?(row.severity)

          row = filter_search(row, search)
          temp << row if row
        end

        if direction == -1
          results = temp + results
        else
          results += temp
        end

        start += limit * direction
        finish += limit * direction

        finish = -1 if finish > -1
      end while rows.length > 0 && results.length < limit && start < 0

      results
    end

    def clear
      RedisRateLimiter.clear_all(@redis)
      @redis.del(solved_key)
      @redis.del(list_key)
      keys = @redis.smembers(protected_key) || []
      if keys.empty?
        @redis.del(hash_key)
      else
        protected = @redis.mapped_hmget(hash_key, *keys)
        @redis.del(hash_key)
        @redis.mapped_hmset(hash_key, protected)

        sorted = protected
          .values
          .map { |string|
            Message.from_json(string) rescue nil
          }
          .compact
          .sort
          .map(&:key)

        @redis.pipelined do
          sorted.each do |message_key|
            @redis.rpush(list_key, message_key)
          end
        end
      end
    end

    # Delete everything, included protected messages
    # (use in tests)
    def clear_all
      @redis.del(list_key)
      @redis.del(protected_key)
      @redis.del(hash_key)
      @redis.del(grouping_key)
      @redis.del(solved_key)
    end

    def get(message_key)
      json = @redis.hget(hash_key, message_key)
      return nil unless json

      Message.from_json(json)
    end

    def protect(message_key)
      if message = get(message_key)
        message.protected = true
        update_message(message)
      end
    end

    def unprotect(message_key)
      if message = get(message_key)
        message.protected = false
        update_message(message)
      else
        raise "Message already deleted"
      end
    end

    def solved
      @redis.hkeys(solved_key) || []
    end

    def register_rate_limit_per_minute(severities, limit, &block)
      register_rate_limit(severities, limit, 60, block)
    end

    def register_rate_limit_per_hour(severities, limit, &block)
      register_rate_limit(severities, limit, 3600, block)
    end

    def redis_prefix
      return 'default'.freeze if !@redis_prefix
      @prefix_is_proc ||= @redis_prefix.respond_to?(:call)
      @prefix_is_proc ? @redis_prefix.call : @redis_prefix
    end

    def rate_limits
      @rate_limits ||= {}
    end

    protected

    def clear_solved(count = nil)

      ignores = Set.new(@redis.hkeys(solved_key) || [])

      if ignores.length > 0
        start = count ? 0 - count : 0
        message_keys = @redis.lrange(list_key, start, -1 ) || []

        @redis.hmget(hash_key, message_keys).each do |json|
          message =  Message.from_json(json)
          unless (ignores & (message.solved_keys || [])).empty?
            delete message
          end
        end
      end
    end

    def trim
      if @redis.llen(list_key) > max_backlog
        removed_keys = []
        while removed_key = @redis.lpop(list_key)
          unless @redis.sismember(protected_key, removed_key)
            rmsg = get removed_key
            @redis.hdel(hash_key, rmsg.key)
            @redis.hdel(grouping_key, rmsg.grouping_key)
            break
          else
            removed_keys << removed_key
          end
        end
        removed_keys.reverse.each do |key|
          @redis.lpush(list_key, key)
        end
      end
    end

    def update_message(message)
      @redis.hset(hash_key, message.key, message.to_json)
      if message.protected
        @redis.sadd(protected_key, message.key)
      else
        @redis.srem(protected_key, message.key)
      end
    end

    def find_message(list, message_key)
      limit = 50
      start = 0
      finish = limit - 1

      found = nil
      while found == nil
        items = @redis.lrange(list, start, finish)

        break unless items && items.length > 0

        found = items.index(message_key)
        break if found

        start += limit
        finish += limit
      end

      found
    end

    def find_location(before, after, limit)
      start = -limit
      finish = -1

      return [start,finish] unless before || after

      found = nil
      find = before || after

      while !found
        items = @redis.lrange(list_key, start, finish)

        break unless items && items.length > 0

        found = items.index(find)

        if items.length < limit
          found += limit - items.length if found
          break
        end
        break if found
        start -= limit
        finish -= limit
      end

      if found
        if before
          offset = -(limit - found)
        else
          offset = found + 1
        end

        start += offset
        finish += offset

        finish = -1 if finish > -1
        return nil if start > -1
      end

      [start, finish]
    end

    def filter_search(row, search)
      return row unless row && search

      if Regexp === search
        row if row.message =~ search
      elsif row.message.include?(search)
        row
      end

    end

    def check_rate_limits(severity)
      rate_limits_to_check = rate_limits[self.redis_prefix]
      return if !rate_limits_to_check
      rate_limits_to_check.each { |rate_limit| rate_limit.check(severity) }
    end

    def solved_key
      @solved_key ||= "__LOGSTER__SOLVED_MAP"
    end

    def list_key
      @list_key ||= "__LOGSTER__LATEST"
    end

    def hash_key
      @hash_key ||= "__LOGSTER__MAP"
    end

    def protected_key
      @saved_key ||= "__LOGSTER__SAVED"
    end

    def grouping_key
      @grouping_key ||= "__LOGSTER__GMAP"
    end

    private

    def register_rate_limit(severities, limit, duration, callback)
      severities = [severities] unless severities.is_a?(Array)
      redis = (@redis_raw_connection && @redis_prefix) ? @redis_raw_connection : @redis

      rate_limiter = RedisRateLimiter.new(
        redis, severities, limit, duration, Proc.new { redis_prefix }, callback
      )

      rate_limits[self.redis_prefix] ||= []
      rate_limits[self.redis_prefix] << rate_limiter
      rate_limiter
    end
  end
end

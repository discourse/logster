# frozen_string_literal: true

require 'json'
require 'logster/base_store'
require 'logster/redis_rate_limiter'

module Logster
  class RedisStore < BaseStore

    attr_accessor :redis, :max_backlog, :redis_raw_connection
    attr_writer :redis_prefix

    def initialize(redis = nil)
      super()
      @redis = redis || Redis.new
      @max_backlog = 1000
      @redis_prefix = nil
      @redis_raw_connection = nil
    end

    def save(message)
      if keys = message.solved_keys
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
        @redis.hdel(env_key, msg.key)
        @redis.hdel(grouping_key, msg.grouping_key)
        @redis.lrem(list_key, -1, msg.key)
      end
    end

    def replace_and_bump(message, save_env: true)
      # TODO make it atomic
      exists = @redis.hexists(hash_key, message.key)
      return false unless exists

      @redis.multi do
        @redis.hset(hash_key, message.key, message.to_json(exclude_env: true))
        @redis.hset(env_key, message.key, (message.env || {}).to_json) if save_env
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

    def latest(opts = {})
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
        break unless keys && (keys.count > 0)
        rows = bulk_get(keys)

        temp = []

        rows.each do |row|
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
        @redis.del(env_key)
      else
        protected = @redis.mapped_hmget(hash_key, *keys)
        protected_env = @redis.mapped_hmget(env_key, *keys)
        @redis.del(hash_key)
        @redis.del(env_key)
        @redis.mapped_hmset(hash_key, protected)
        @redis.mapped_hmset(env_key, protected_env)

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
      @redis.del(env_key)
      @redis.del(grouping_key)
      @redis.del(solved_key)
      @redis.del(ignored_logs_count_key)
      Logster::PATTERNS.each do |klass|
        @redis.del(klass.set_name)
      end
      @redis.keys.each do |key|
        @redis.del(key) if key.include?(Logster::RedisRateLimiter::PREFIX)
        @redis.del(key) if key.start_with?(ip_rate_limit_key(""))
      end
    end

    def get(message_key, load_env: true)
      json = @redis.hget(hash_key, message_key)
      return nil unless json

      message = Message.from_json(json)
      if load_env
        message.env = get_env(message_key) || {}
      end
      message
    end

    def bulk_get(message_keys)
      envs = @redis.hmget(env_key, message_keys)
      @redis.hmget(hash_key, message_keys).map!.with_index do |json, ind|
        message = Message.from_json(json)
        env = envs[ind]
        if !message.env || message.env.size == 0
          env = env && env.size > 0 ? ::JSON.parse(env) : {}
          message.env = env
        end
        message
      end
    end

    def get_env(message_key)
      json = @redis.hget(env_key, message_key)
      return if !json || json.size == 0
      JSON.parse(json)
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

    def insert_pattern(set_name, pattern)
      @redis.sadd(set_name, pattern)
    end

    def remove_pattern(set_name, pattern)
      @redis.srem(set_name, pattern)
    end

    def get_patterns(set_name)
      @redis.smembers(set_name)
    end

    def increment_ignore_count(pattern)
      @redis.hincrby(ignored_logs_count_key, pattern, 1)
    end

    def remove_ignore_count(pattern)
      @redis.hdel(ignored_logs_count_key, pattern)
    end

    def get_all_ignore_count
      @redis.hgetall(ignored_logs_count_key)
    end

    def rate_limited?(ip_address, perform: false, limit: 60)
      key = ip_rate_limit_key(ip_address)

      limited = @redis.exists(key)

      if perform && !limited
        @redis.setex key, limit, ""
      end

      limited
    end

    protected

    def clear_solved(count = nil)

      ignores = Set.new(@redis.hkeys(solved_key) || [])

      if ignores.length > 0
        start = count ? 0 - count : 0
        message_keys = @redis.lrange(list_key, start, -1) || []

        bulk_get(message_keys).each do |message|
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
            @redis.hdel(env_key, rmsg.key)
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
      @redis.hset(hash_key, message.key, message.to_json(exclude_env: true))
      @redis.hset(env_key, message.key, (message.env || {}).to_json)
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

      return [start, finish] unless before || after

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

    def get_search(search)
      exclude = false
      if String === search && search[0] == "-"
        exclude = true
        search = search.sub("-", "")
      end
      [search, exclude]
    end

    def filter_search(row, search)
      search, exclude = get_search(search)
      return row unless row && search

      if exclude
        row if !(row =~ search) && filter_env!(row, search, exclude)
      else
        row if row =~ search || filter_env!(row, search)
      end
    end

    def filter_env!(message, search, exclude = false)
      if Array === message.env
        array_env_matches?(message, search, exclude)
      else
        if exclude
          !env_matches?(message.env, search)
        else
          env_matches?(message.env, search)
        end
      end
    end

    def env_matches?(env, search)
      return false unless env && search

      env.values.any? do |value|
        if Hash === value
          env_matches?(value, search)
        else
          case search
          when Regexp
            value.to_s =~ search
          when String
            value.to_s =~ Regexp.new(search, Regexp::IGNORECASE)
            else
            false
          end
        end
      end
    end

    def array_env_matches?(message, search, exclude)
      matches = message.env.select do |env|
        if exclude
          !env_matches?(env, search)
        else
          env_matches?(env, search)
        end
      end
      return false if matches.empty?
      message.env = matches
      message.count = matches.size
      true
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

    def env_key
      @env_key ||= "__LOGSTER__ENV_MAP"
    end

    def protected_key
      @saved_key ||= "__LOGSTER__SAVED"
    end

    def grouping_key
      @grouping_key ||= "__LOGSTER__GMAP"
    end

    def ignored_logs_count_key
      @ignored_logs_count_key ||= "__LOGSTER__IGNORED_LOGS_COUNT_KEY__MAP"
    end

    def ip_rate_limit_key(ip_address)
      "__LOGSTER__IP_RATE_LIMIT_#{ip_address}"
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

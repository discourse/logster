require 'json'
require 'logster/base_store'

module Logster
  class RedisStore < BaseStore

    attr_accessor :redis, :max_backlog

    def initialize(redis = nil)
      super()
      @redis = redis || Redis.new
      @max_backlog = 1000
    end


    def save(message)
      @redis.multi do
        @redis.hset(grouping_key, message.grouping_key, message.key)
        @redis.rpush(list_key, message.key)
        update_message(message)
      end

      trim

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

      true
    end

    def similar_key(message)
      @redis.hget(grouping_key, message.grouping_key)
    end

    def count
      @redis.llen(list_key)
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
          .map { |string| Message.from_json(string) }
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

    protected

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
  end
end

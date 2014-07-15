require 'json'

module Logster
  class RedisStore

    attr_accessor :level, :redis, :max_backlog,
                  :dedup, :max_retention, :skip_empty,
                  :ignore

    def initialize(redis = nil)
      @redis = redis || Redis.new
      @max_backlog = 1000
      @dedup = false
      @max_retention = 60 * 60 * 24 * 7
      @skip_empty = true
    end


    def report(severity, progname, message, opts = nil)
      return if (!message || (String === message && message.empty?)) && skip_empty
      return if level && severity < level
      return if @ignore && @ignore.any?{|pattern| message =~ pattern}
      opts ||= {}
      env = opts[:env]
      backtrace = opts[:backtrace]
      if env && !backtrace
        backtrace = env[:backtrace]
      end

      if Logster.config.group_errors
        # Retrieve the last message
        last_key = @redis.lindex(list_key, -1)
        if last_key
          last_message = get(last_key)
          if last_message.should_combine?(severity, progname, message, backtrace)
            # Combine the messages
            last_message.count += 1

            old_env = last_message.env
            last_message.env = nil
            last_message.populate_from_env(env)
            new_env = last_message.env

            if old_env != new_env

            end

            @redis.hset(hash_key, last_key, last_message.to_json)

            return last_message
          end
        end
      end

      message = Logster::Message.new(severity, progname, message)

      if backtrace
        message.backtrace = backtrace
      else
        message.backtrace = caller.join("\n")
      end

      if env
        message.populate_from_env(env)
      end

      # multi for integrity
      @redis.multi do
        @redis.hset(hash_key, message.key, message.to_json)
        @redis.rpush(list_key, message.key)
      end

      # TODO make it atomic
      if @redis.llen(list_key) > @max_backlog
        removed_key = @redis.lpop(list_key)
        if removed_key && !@redis.sismember(protected_key, removed_key)
          @redis.hdel(hash_key, removed_key)
        end
      end

      message
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
      end
    end

    def clear_all
      @redis.del(list_key)
      @redis.del(protected_key)
      @redis.del(hash_key)
    end

    def get(message_key)
      json = @redis.hget(hash_key, message_key)
      return nil unless json

      message = Message.from_json(json)
      message.protected = @redis.sismember(protected_key, message_key)
      message
    end

    def protect(message_key)
      json = @redis.hget(hash_key, message_key)
      # Message already lost
      return false unless json

      @redis.sadd(protected_key, message_key)

      true
    end

    def unprotect(message_key)
      value = @redis.hget(hash_key, message_key)
      # this is a failure of retention
      raise "Message already deleted?" unless value

      @redis.srem(protected_key, message_key)

      index = find_message(list_key, message_key)
      if index == nil
        # Message fell off list - delete
        @redis.hdel(hash_key, message_key)
      end

      true
    end

    protected

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
  end
end

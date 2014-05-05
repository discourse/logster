require 'json'

module Logster
  class RedisStore

    attr_accessor :max_backlog, :dedup, :max_retention, :skip_empty

    def initialize(redis = nil)
      @redis = redis || Redis.new
      @max_backlog = 1000
      @dedup = false
      @max_retention = 60 * 60 * 24 * 7
      @skip_empty = true
    end


    def report(severity, progname, message)
      return if (!message || (String === message && message.empty?)) && skip_empty

      message = Message.new(severity, progname, message)
      @redis.rpush(list_key, message.to_json)

      # TODO make it atomic
      if @redis.llen(list_key) > @max_backlog
        @redis.lpop(list_key)
      end

      nil
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
      regex = opts[:regex]
      start = -limit
      finish = -1

      if before || after
        # inefficient may change to sorted list, also timing issues
        found = nil
        find = before || after

        while !found
          items = @redis.lrange(list_key, start, finish)

          break unless items && items.length > 0

          found = items.index do |i|
            Message.from_json(i).key == find
          end

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
          return [] if start > -1
        end
      end

      results = []

      direction = after ? 1 : -1

      begin
        rows = @redis.lrange(list_key, start, finish) || []

        temp = []

        rows.each do |s|
          row = Message.from_json(s)
          break if before && before == row.key
          row = nil if severity && !severity.include?(row.severity)
          if row && search
            if regex == "true"
              unless Regexp.new(search) =~ row.message
                row = nil
              end
            else
              unless row.message.include?(search)
                row = nil
              end
            end
          end
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

    def clear(severities=nil)
      @redis.del(list_key)
    end

    protected


    def list_key
      @list_key ||= "__LOGSTER__LOG"
    end

  end
end

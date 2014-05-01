require 'json'

module Logster
  class RedisStore

    class Row
      attr_accessor :timestamp, :severity, :progname, :message, :key

      def initialize(severity, progname, message, timestamp = nil, key = nil)
        @timestamp = timestamp || get_timestamp
        @severity = severity
        @progname = progname
        @message = message
        @key = key || SecureRandom.hex
      end

      def to_h
        {
          message: @message,
          progname: @progname,
          severity: @severity,
          timestamp: @timestamp,
          key: @key
        }
      end

      def to_json(opts=nil)
        JSON.fast_generate(to_h,opts)
      end

      def self.from_json(json)
        parsed = ::JSON.parse(json)
        new( parsed["severity"],
              parsed["progname"],
              parsed["message"],
              parsed["timestamp"],
              parsed["key"] )
      end

      protected

      def get_timestamp
        (Time.new.to_f * 1000).to_i
      end
    end

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

      message = Row.new(severity, progname, message)
      @redis.rpush(list_key, message.to_json)

      # TODO make it atomic
      if @redis.llen(list_key) > @max_backlog
        @redis.lpop(list_key)
      end
    end

    def count
      @redis.llen(list_key)
    end

    def latest(opts={})
      limit = opts[:limit] || 50
      severity = opts[:severity]
      before = opts[:before]
      after = opts[:after]
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
            Row.from_json(i).key == find
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

      (@redis.lrange(list_key, start, finish) || []).each do |s|
        row = Row.from_json(s)
        row = nil if severity && !severity.include?(row.severity)
        break if before && before == row.key
        results << row if row
      end

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

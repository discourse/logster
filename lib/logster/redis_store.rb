require 'json'

module Logster
  class RedisStore

    class Row
      attr_accessor :timestamp, :severity, :progname, :message

      def initialize(severity, progname, message, timestamp = nil)
        @timestamp = timestamp || get_timestamp
        @severity = severity
        @progname = progname
        @message = message
      end

      def to_json
        JSON.fast_generate({
          message: @message,
          progname: @progname,
          severity: @severity,
          timestamp: @timestamp
        })
      end

      def self.from_json(json)
        parsed = ::JSON.parse(json)
        new(parsed["severity"], parsed["progname"], parsed["message"], parsed["timestamp"])
      end

      protected

      def get_timestamp
        (Time.new.to_f * 1000).to_i
      end
    end

    attr_accessor :max_backlog, :dedup, :max_retention

    def initialize(redis)
      @redis = redis
      @max_backlog = 1000
      @dedup = false
      @max_retention = 60 * 60 * 24 * 7
    end


    def report(severity, progname, message)
      message = Row.new(severity, progname, message)
      @redis.rpush(list_key, message.to_json)
    end

    def latest(severities=nil,limit=50)
      (@redis.lrange(list_key, -limit, limit) || []).map! do |s|
        Row.from_json(s)
      end
    end

    def clear(severities=nil)
      @redis.del(list_key)
    end

    protected


    def list_key
      "__LOGSTER__LOG"
    end

  end
end

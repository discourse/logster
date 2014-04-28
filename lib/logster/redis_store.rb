module Logster
  class RedisStore
    attr_accessor :max_backlog, :dedup

    def initialize(redis)
      @redis = redis
      @max_backlog = 1000
      @dedup = false
    end


    def report(severity, progname, message, key=nil)
    end

    def latest(severities=nil,limit=50)
    end

    def clear(severities=nil)
    end

  end
end

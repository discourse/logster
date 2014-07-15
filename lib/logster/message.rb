module Logster
  class Message
    LOGSTER_ENV = "_logster_env".freeze
    ALLOWED_ENV = %w{
      HTTP_HOST
      REQUEST_URI
      REQUEST_METHOD
      HTTP_USER_AGENT
      HTTP_ACCEPT
      HTTP_REFERER
      HTTP_X_FORWARDED_FOR
      HTTP_X_REAL_IP
    }

    attr_accessor :timestamp, :severity, :progname, :message, :key, :backtrace, :count, :env, :protected

    def initialize(severity, progname, message, timestamp = nil, key = nil)
      @timestamp = timestamp || get_timestamp
      @severity = severity
      @progname = progname
      @message = message
      @key = key || SecureRandom.hex
      @backtrace = nil
      @count = 1
      @protected = false
    end

    def to_h
      {
        message: @message,
        progname: @progname,
        severity: @severity,
        timestamp: @timestamp,
        key: @key,
        backtrace: @backtrace,
        count: @count,
        env: @env,
        protected: @protected
      }
    end

    def to_json(opts = nil)
      JSON.fast_generate(to_h, opts)
    end

    def self.from_json(json)
      parsed = ::JSON.parse(json)
      msg = new( parsed["severity"],
            parsed["progname"],
            parsed["message"],
            parsed["timestamp"],
            parsed["key"] )
      msg.backtrace = parsed["backtrace"]
      msg.env = parsed["env"]
      msg.count = parsed["count"]
      msg
    end

    def populate_from_env(env)
      @env = Message.populate_from_env(env)
    end


    def self.populate_from_env(env)
      env[LOGSTER_ENV] ||= begin
          unless env.include? "rack.input"
            # Not a web request
            return env
          end
          scrubbed = {}
          request = Rack::Request.new(env)
          params = {}
          request.params.each do |k,v|
            if k.include? "password"
              params[k] = "[redacted]"
            else
              params[k] = v[0..100]
            end
          end
          scrubbed["params"] = params if params.length > 0
          ALLOWED_ENV.map{ |k|
           scrubbed[k] = env[k] if env[k]
          }
          scrubbed
      end
    end

    def <=>(other)
      time = self.timestamp <=> other.timestamp
      return time if time && time != 0

      self.key <=> other.key
    end

    protected

    def get_timestamp
      (Time.new.to_f * 1000).to_i
    end
  end
end

require 'digest/sha1'

module Logster

  MAX_GROUPING_LENGTH = 50

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
      hostname
      process_id
      application_version
    }

    attr_accessor :timestamp, :severity, :progname, :message, :key, :backtrace, :count, :env, :protected, :first_timestamp

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
      h = {
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

      if @first_timestamp
        h[:first_timestamp] = @first_timestamp
      end

      h
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
      msg.protected = parsed["protected"]
      msg.first_timestamp = parsed["first_timestamp"]
      msg
    end

    def self.hostname
      @hostname ||= `hostname`.strip! rescue "<unknown>"
    end

    def populate_from_env(env)
      env ||= {}
      @env = Message.populate_from_env(self.class.default_env.merge env)
    end

    def self.default_env
      env = {
        "hostname" => hostname,
        "process_id" => Process.pid
      }
      env["application_version"] = Logster.config.application_version if Logster.config.application_version
      env
    end

    # in its own method so it can be overridden
    def grouping_hash
      return { message: self.message, severity: self.severity, backtrace: self.backtrace }
    end

    # todo - memoize?
    def grouping_key
      Digest::SHA1.hexdigest JSON.fast_generate grouping_hash
    end

    # todo - memoize?
    def solved_keys
      if (versions=env["application_version"]) &&
          (backtrace && backtrace.length > 0)
        versions = [versions] if String === versions

        versions.map do |version|
          Digest::SHA1.hexdigest "#{version} #{backtrace}"
        end
      end
    end

    def is_similar?(other)
      self.grouping_key == other.grouping_key
    end

    def merge_similar_message(other)
      self.first_timestamp ||= self.timestamp
      self.timestamp = [self.timestamp,other.timestamp].max
      other_env = JSON.load JSON.fast_generate other.env
      other_env.keys.each do |env_key|
        self.env[env_key] = Message.env_merge_helper(self.env[env_key], other_env[env_key])
      end
    end

    def self.populate_from_env(env)
      env[LOGSTER_ENV] ||= begin
          unless env.include? "rack.input"
            # Not a web request
            return env
          end
          scrubbed = default_env
          request = Rack::Request.new(env)
          params = {}
          request.params.each do |k,v|
            if k.include? "password"
              params[k] = "[redacted]"
            elsif Array === v
              params[k] = v[0..20]
            else
              params[k] = v && v[0..100]
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

    def =~(pattern)
      case pattern
        when Hash
          IgnorePattern.new(nil, pattern).matches? self
        when String
          IgnorePattern.new(pattern, nil).matches? self
        when Regexp
          IgnorePattern.new(pattern, nil).matches? self
        when IgnorePattern
          pattern.matches? self
        else
          nil
      end
    end

    protected

    def get_timestamp
      (Time.new.to_f * 1000).to_i
    end

    private

    def self.env_merge_helper(self_value, other_value)
      other_value = other_value.to_s if Symbol === other_value

      if (Hash === self_value || self_value.nil?) && (Hash === other_value || other_value.nil?) && (!self_value.nil? || !other_value.nil?)
        # one or both is a hash but not neither -> recurse on the keys
        self_value = {} unless self_value
        other_value = {} unless other_value
        shared_keys = self_value.keys | (other_value.keys rescue [])
        shared_keys.each do |key|
          self_value[key] = env_merge_helper(self_value[key], other_value[key])
        end
        self_value
      elsif self_value.is_a?(Array) && !other_value.is_a?(Array)
        # Already have grouped data, so append to array (it's actually a set)
        self_value << other_value unless self_value.include?(other_value) || self_value.length >= Logster::MAX_GROUPING_LENGTH
        self_value
      elsif !self_value.is_a?(Array)
        if self_value == other_value
          self_value
        else
          [self_value, other_value]
        end
      else
        # They're both arrays.
        # Three cases:
        # self = [1,2,3] and other = [1,2,4] -> make into array of array
        # self = [] and other = [1,2,4] -> make into array of array
        # self = [[1,2,3], [1,2,5]] and other = [1,2,4] -> append to array
        if self_value.length > 0 && self_value[0].is_a?(Array)
          self_value << other_value unless self_value.include?(other_value) || self_value.length >= Logster::MAX_GROUPING_LENGTH
          self_value
        else
          if self_value == other_value
            self_value
          else
            [self_value, other_value]
          end
        end
      end
    end
  end
end

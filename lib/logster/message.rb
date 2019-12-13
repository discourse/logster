# frozen_string_literal: true

require 'digest/sha1'
require 'securerandom'

module Logster

  MAX_GROUPING_LENGTH = 50
  MAX_MESSAGE_LENGTH = 600

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

    attr_accessor :timestamp, :severity, :progname, :key, :backtrace, :count, :protected, :first_timestamp
    attr_reader :message, :env

    def initialize(severity, progname, message, timestamp = nil, key = nil, count: 1)
      @timestamp = timestamp || get_timestamp
      @severity = severity
      @progname = progname
      @message = truncate_message(message)
      @key = key || SecureRandom.hex
      @backtrace = nil
      @count = count || 1
      @protected = false
      @first_timestamp = nil
    end

    def to_h(exclude_env: false)
      h = {
        message: @message,
        progname: @progname,
        severity: @severity,
        timestamp: @timestamp,
        key: @key,
        backtrace: @backtrace,
        count: @count,
        protected: @protected
      }

      h[:first_timestamp] = @first_timestamp if @first_timestamp
      h[:env] = @env unless exclude_env

      h
    end

    def message=(m)
      @message = truncate_message(m)
    end

    def to_json(opts = nil)
      exclude_env = Hash === opts && opts.delete(:exclude_env)
      JSON.fast_generate(to_h(exclude_env: exclude_env), opts)
    end

    def self.from_json(json)
      parsed = ::JSON.parse(json)
      msg = new(parsed["severity"],
            parsed["progname"],
            parsed["message"],
            parsed["timestamp"],
            parsed["key"])
      msg.backtrace = parsed["backtrace"]
      msg.env = parsed["env"]
      msg.count = parsed["count"]
      msg.protected = parsed["protected"]
      msg.first_timestamp = parsed["first_timestamp"]
      msg
    end

    def env=(env)
      @env_json = nil
      @env = self.class.scrub_params(env)
    end

    def self.hostname
      @hostname ||= `hostname`.strip! rescue "<unknown>"
    end

    def populate_from_env(env)
      env ||= {}
      if Array === env
        env = env.map do |single_env|
          self.class.default_env.merge(single_env)
        end
      else
        env = self.class.default_env.merge(env)
      end
      @env_json = nil
      @env = Message.populate_from_env(env)
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
      { message: self.message, severity: self.severity, backtrace: self.backtrace }
    end

    # todo - memoize?
    def grouping_key
      Digest::SHA1.hexdigest JSON.fast_generate grouping_hash
    end

    # todo - memoize?
    def solved_keys
      if Array === env
        versions = env.map { |single_env| single_env["application_version"] }
      else
        versions = env["application_version"]
      end

      if versions && backtrace && backtrace.length > 0
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
      self.timestamp = [self.timestamp, other.timestamp].max

      self.count += other.count || 1
      return false if self.count > Logster::MAX_GROUPING_LENGTH

      size = self.to_json(exclude_env: true).bytesize + self.env_json.bytesize
      extra_env_size = other.env_json.bytesize
      return false if size + extra_env_size > Logster.config.maximum_message_size_bytes

      other_env = JSON.load JSON.fast_generate other.env
      if Hash === other_env && !other_env.key?("time")
        other_env["time"] = other.timestamp
      end
      if Hash === self.env && !self.env.key?("time")
        self.env["time"] = self.first_timestamp
      end

      if Array === self.env
        Array === other_env ? self.env.concat(other_env) : self.env << other_env
      else
        Array === other_env ? self.env = [self.env, *other_env] : self.env = [self.env, other_env]
      end
      @env_json = nil
      true
    end

    def self.populate_from_env(env)
      if Array === env
        env.map do |single_env|
          self.populate_env_helper(single_env)
        end
      else
        self.populate_env_helper(env)
      end
    end

    def self.populate_env_helper(env)
      env[LOGSTER_ENV] ||= begin
        unless env.include? "rack.input"
          # Not a web request
          return env
        end
        scrubbed = default_env
        request = Rack::Request.new(env)
        params = {}
        request.params.each do |k, v|
          if k.include? "password"
            params[k] = "[redacted]"
          elsif Array === v
            params[k] = v[0..20]
          else
            params[k] = v && v[0..100]
          end
        end
        scrubbed["params"] = params if params.length > 0
        ALLOWED_ENV.map { |k|
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

    def env_json
      @env_json ||= (self.env || {}).to_json
    end

    def self.scrub_params(params)
      if Array === params
        params.map! { |p| scrub_params(p) }
        params
      elsif Hash === params
        params.each do |k, v|
          params[k] = scrub_params(v)
        end
        params
      elsif String === params
        scrubbed = params.scrub if !params.valid_encoding?
        scrubbed || params
      else
        params
      end
    end

    protected

    def truncate_message(msg)
      return msg unless msg
      msg = msg.inspect unless String === msg
      msg.size <= MAX_MESSAGE_LENGTH ? msg : msg[0...MAX_MESSAGE_LENGTH] + "..."
    end

    def get_timestamp
      (Time.new.to_f * 1000).to_i
    end
  end
end

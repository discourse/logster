# frozen_string_literal: true

require 'digest/sha1'
require 'securerandom'

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
      hostname
      process_id
      application_version
      time
    }

    attr_accessor :timestamp, :severity, :progname, :key, :backtrace, :count, :protected, :first_timestamp, :env_buffer
    attr_reader :message, :env

    def initialize(severity, progname, message, timestamp = nil, key = nil, count: 1)
      @timestamp = timestamp || get_timestamp
      @severity = severity
      @progname = progname
      @message = message
      @key = key || SecureRandom.hex
      @backtrace = nil
      @count = count || 1
      @protected = false
      @first_timestamp = nil
      @env_buffer = []
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
      @env = self.class.scrub_params(env)
    end

    def self.hostname
      @hostname ||= `hostname`.strip! rescue "<unknown>"
    end

    def populate_from_env(env)
      env ||= {}
      if Array === env
        env = env.map do |single_env|
          single_env = self.class.default_env.merge(single_env)
          if !single_env.key?("time") && !single_env.key?(:time)
            single_env["time"] = @timestamp || get_timestamp
          end
          single_env
        end
      else
        env = self.class.default_env.merge(env)
        if !env.key?("time") && !env.key?(:time)
          env["time"] = @timestamp || get_timestamp
        end
      end
      self.env = Message.populate_from_env(env)
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
      message = self.message.gsub(/[0-9a-f]+/i, "X")
      { message: message, severity: self.severity, backtrace: self.backtrace }
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
        versions = [env["application_version"]]
      end
      versions.compact!

      if backtrace && backtrace.length > 0
        versions.map do |version|
          Digest::SHA1.hexdigest "#{version} #{backtrace}"
        end
      end
    end

    def merge_similar_message(other)
      self.first_timestamp ||= self.timestamp
      self.timestamp = [self.timestamp, other.timestamp].max
      self.count += other.count || 1

      if Hash === other.env && !other.env.key?("time") && !other.env.key?(:time)
        other.env["time"] = other.timestamp
      end

      if Array === other.env
        env_buffer.unshift(*other.env)
      else
        env_buffer.unshift(other.env)
      end
      true
    end

    def has_env_buffer?
      env_buffer.size > 0
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

    def drop_redundant_envs(limit)
      if Array === env
        env.slice!(limit..-1)
      end
    end

    def apply_env_size_limit(size_limit)
      if Array === env
        env.each { |e| truncate_env(e, size_limit) }
      elsif Hash === env
        truncate_env(env, size_limit)
      end
    end

    def apply_message_size_limit(limit, gems_dir: nil)
      size = self.to_json(exclude_env: true).bytesize
      if size > limit && @backtrace
        @backtrace.gsub!(gems_dir, "") if gems_dir
        @backtrace.strip!
        size = self.to_json(exclude_env: true).bytesize
        backtrace_limit = limit - (size - @backtrace.bytesize)
        return if backtrace_limit <= 0 || size <= limit
        truncate_backtrace(backtrace_limit)
      end
    end

    def truncate_backtrace(bytes_limit)
      @backtrace = @backtrace.byteslice(0...bytes_limit)
      while !@backtrace[-1].valid_encoding? && @backtrace.size > 1
        @backtrace.slice!(-1)
      end
    end

    protected

    def truncate_env(env, limit)
      if JSON.fast_generate(env).bytesize > limit
        sizes = {}
        braces = '{}'.bytesize
        env.each do |k, v|
          sizes[k] = JSON.fast_generate(k => v).bytesize - braces
        end
        sorted = env.keys.sort { |a, b| sizes[a] <=> sizes[b] }

        kept_keys = []
        if env.key?(:time)
          kept_keys << :time
        elsif env.key?("time")
          kept_keys << "time"
        end

        sum = braces
        if time_key = kept_keys.first
          sum += sizes[time_key]
          sorted.delete(time_key)
        end
        comma = ','.bytesize

        sorted.each do |k|
          extra = kept_keys.size == 0 ? 0 : comma
          break if sum + sizes[k] + extra > limit
          kept_keys << k
          sum += sizes[k] + extra
        end
        env.select! { |k| kept_keys.include?(k) }
      end
    end

    def get_timestamp
      (Time.now.to_f * 1000).to_i
    end
  end
end

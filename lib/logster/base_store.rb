
module Logster
  class BaseStore

    attr_accessor :level, :max_retention, :skip_empty, :ignore

    def initialize
      @dedup = false
      @max_retention = 60 * 60 * 24 * 7
      @skip_empty = true
    end

    def save(message)
      not_implemented
    end

    def count
      not_implemented
    end

    def clear
      not_implemented
    end

    def clear_all
      not_implemented
    end

    def get(message_key)
      not_implemented
    end

    def protect(message_key)
      not_implemented
    end

    def unprotect(message_key)
      not_implemented
    end

    def report(severity, progname, msg, opts = {})
      return if (!msg || (String === msg && msg.empty?)) && skip_empty
      return if level && severity < level

      message = Logster::Message.new(severity, progname, msg, opts[:timestamp])

      env = opts[:env]
      backtrace = opts[:backtrace]

      if env
        if env[:backtrace]
          # Special - passing backtrace through env
          backtrace = env.delete(:backtrace)
        end

        message.populate_from_env(env)
      end

      if backtrace
        if backtrace.respond_to? :join
          backtrace = backtrace.join("\n")
        end
        message.backtrace = backtrace
      else
        message.backtrace = caller.join("\n")
      end

      return if ignore && ignore.any? { |pattern| message =~ pattern}

      save message

      message
    end

    private

    def not_implemented
      raise "Not Implemented"
    end
  end
end

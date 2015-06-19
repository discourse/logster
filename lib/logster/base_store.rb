
module Logster
  class BaseStore

    attr_accessor :level, :max_retention, :skip_empty, :ignore

    def initialize
      @dedup = false
      @max_retention = 60 * 60 * 24 * 7
      @skip_empty = true
    end

    # Save a new message at the front of the latest list
    def save(message)
      not_implemented
    end

    # Modify the saved message to the given one (identified by message.key) and bump it to the top of the latest list
    def replace_and_bump(message)
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

      env = opts[:env] || {}
      backtrace = opts[:backtrace]

      if env[:backtrace]
        # Special - passing backtrace through env
        backtrace = env.delete(:backtrace)
      end

      message.populate_from_env(env)

      if backtrace
        if backtrace.respond_to? :join
          backtrace = backtrace.join("\n")
        end
        message.backtrace = backtrace
      else
        message.backtrace = caller.join("\n")
      end

      return if ignore && ignore.any? { |pattern| message =~ pattern}

      recent = latest(limit: 10, severity: [severity])
      puts recent.length
      similar = recent.find { |smessage| smessage.is_similar?(message) }

      if similar
        similar.count += 1

        replace_and_bump similar
        similar
      else
        save message
        message
      end
    end

    private

    def not_implemented
      raise "Not Implemented"
    end
  end
end

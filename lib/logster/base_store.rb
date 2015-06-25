
module Logster
  class BaseStore

    attr_accessor :level, :max_retention, :skip_empty, :ignore

    def initialize
      @dedup = false
      @max_retention = 60 * 60 * 24 * 7
      @skip_empty = true
    end

    # Save a new message at the front of the latest list.
    def save(message)
      not_implemented
    end

    # Modify the saved message to the given one (identified by message.key) and bump it to the top of the latest list
    def replace_and_bump(message)
      not_implemented
    end

    # Check if another message with the same grouping_key is already stored.
    # Returns the similar message's message.key
    def similar_key(message)
      not_implemented
    end

    # The number of messages currently stored.
    def count
      not_implemented
    end

    # Delete all unprotected messages in the store.
    def clear
      not_implemented
    end

    # Delete all messages, including protected messages.
    def clear_all
      not_implemented
    end

    # Get a message by its message_key
    def get(message_key)
      not_implemented
    end

    # Mark a message as protected; i.e. it is not deleted by the #clear method
    def protect(message_key)
      not_implemented
    end

    # Clear the protected mark for a message.
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

      similar = nil

      if Logster.config.allow_grouping || true
        key = self.similar_key(message)
        similar = get key if key
      end

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

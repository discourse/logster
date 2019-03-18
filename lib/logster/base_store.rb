module Logster
  class BaseStore

    attr_accessor :level, :max_retention, :skip_empty, :ignore, :allow_custom_ignore

    def initialize
      @max_retention = 60 * 60 * 24 * 7
      @skip_empty = true
      @allow_custom_ignore = false
      @patterns_cache = Logster::Cache.new
    end

    # Save a new message at the front of the latest list.
    def save(message)
      not_implemented
    end

    # Modify the saved message to the given one (identified by message.key) and bump it to the top of the latest list
    def replace_and_bump(message, save_env: true)
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
    def get(message_key, load_env: true)
      not_implemented
    end

    # Get a group of messages by their message_keys
    def bulk_get(message_keys)
      not_implemented
    end

    # Get a message's env by its message_key
    def get_env(message_key)
      not_implemented
    end

    # Mark a message as protected; i.e. it is not deleted by the #clear method
    def protect(message_key)
      not_implemented
    end

    def delete(message_key)
      not_implemented
    end

    # Clear the protected mark for a message.
    def unprotect(message_key)
      not_implemented
    end

    # Solve a particular message, causing all old messages with matching version and backtrace
    # to be deleted (report should delete any solved messages when called)
    def solve(message_key)
      not_implemented
    end

    # Registers a rate limit on the given severities of logs
    def register_rate_limit(severities, limit, duration, &block)
      not_implemented
    end

    # Checks all the existing rate limiters to check if any has been exceeded
    def check_rate_limits(severity)
      not_implemented
    end

    # takes a string as `pattern` and places it under the set `set_name`
    def insert_pattern(set_name, pattern)
      not_implemented
    end

    # takes a string as `pattern` and removes it from the set `set_name`
    def remove_pattern(set_name, pattern)
      not_implemented
    end

    # returns an array of strings each of which must be convertible to regexp
    def get_patterns(set_name)
      not_implemented
    end

    def report(severity, progname, msg, opts = {})
      return if (!msg || (String === msg && msg.empty?)) && skip_empty
      return if level && severity < level

      message = Logster::Message.new(severity, progname, msg, opts[:timestamp], count: opts[:count])

      env = opts[:env] || {}
      backtrace = opts[:backtrace]
      if Hash === env && env[:backtrace]
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

      return if ignore && ignore.any? { |pattern| message =~ pattern }

      if Logster.config.enable_custom_patterns_via_ui || allow_custom_ignore
        custom_ignore = @patterns_cache.fetch do
          Logster::SuppressionPattern.find_all(store: self)
        end
        return if custom_ignore.any? { |pattern| message =~ pattern }
      end

      similar = nil

      if Logster.config.allow_grouping
        key = self.similar_key(message)
        similar = get(key, load_env: false) if key
      end

      if similar
        has_env = !similar.env.nil? && !similar.env.empty?
        if similar.count < Logster::MAX_GROUPING_LENGTH && !has_env
          similar.env = get_env(similar.key) || {}
        end
        save_env = similar.merge_similar_message(message)

        replace_and_bump(similar, save_env: save_env || has_env)
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

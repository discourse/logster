# frozen_string_literal: true

module Logster
  class BaseStore

    attr_accessor :level, :max_retention, :skip_empty, :ignore, :allow_custom_patterns

    def initialize
      @max_retention = 60 * 60 * 24 * 7
      @skip_empty = true
      @allow_custom_patterns = false
      @patterns_cache = Logster::Cache.new
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
    def get(message_key, load_env: true)
      not_implemented
    end

    # Get a group of messages by their message_keys
    def bulk_get(message_keys)
      not_implemented
    end

    # Get all messages that you have in the store
    def get_all_messages
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

    # Delete messages associated with given message_keys
    def bulk_delete(message_keys, grouping_keys)
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

    # increments the number of messages that have been suppressed by a pattern
    def increment_ignore_count(pattern)
      not_implemented
    end

    # removes number of suppressed messages by a pattern
    def remove_ignore_count(pattern)
      not_implemented
    end

    # returns a hash that maps patterns to the number of messages they
    # have suppressed
    def get_all_ignore_count
      not_implemented
    end

    def rate_limited?(ip_address, perform: false, limit: 60)
      not_implemented
    end

    # find all pattern groups; returns an array of Logster::Group
    def find_pattern_groups(load_messages: true)
      not_implemented
    end

    # saves an instance of Logster::Group
    def save_pattern_group(group)
      not_implemented
    end

    # removes the Logster::Group instance associated with the given pattern
    def remove_pattern_group(pattern)
      not_implemented
    end

    def report(severity, progname, msg, opts = {})
      return if (!msg || (String === msg && msg.empty?)) && skip_empty
      return if level && severity < level

      msg = msg.inspect unless String === msg
      msg = truncate_message(msg)
      message = Logster::Message.new(severity, progname, msg, opts[:timestamp], count: opts[:count])

      env = opts[:env]&.dup || {}
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

      return if ignore && ignore.any? do |pattern|
        if message =~ pattern
          val = Regexp === pattern ? pattern.inspect : pattern.to_s
          increment_ignore_count(val)
          true
        end
      end

      if Logster.config.enable_custom_patterns_via_ui || allow_custom_patterns
        custom_ignore = @patterns_cache.fetch(Logster::SuppressionPattern::CACHE_KEY) do
          Logster::SuppressionPattern.find_all(store: self)
        end
        return if custom_ignore.any? do |pattern|
          if message =~ pattern
            increment_ignore_count(pattern.inspect)
            true
          end
        end
      end

      similar = nil

      if Logster.config.allow_grouping
        message.apply_message_size_limit(
          Logster.config.maximum_message_size_bytes,
          gems_dir: Logster.config.gems_dir
        )
        key = self.similar_key(message)
        similar = get(key, load_env: false) if key
      end

      message.drop_redundant_envs(Logster.config.max_env_count_per_message)
      message.apply_env_size_limit(Logster.config.max_env_bytes)
      saved = true
      if similar
        similar.merge_similar_message(message)
        replace_and_bump(similar)
        similar
      else
        message.apply_message_size_limit(
          Logster.config.maximum_message_size_bytes,
          gems_dir: Logster.config.gems_dir
        )
        saved = save(message)
        message
      end

      message = similar || message

      if (Logster.config.enable_custom_patterns_via_ui || allow_custom_patterns) && saved
        grouping_patterns = @patterns_cache.fetch(Logster::GroupingPattern::CACHE_KEY) do
          Logster::GroupingPattern.find_all(store: self)
        end

        grouping_patterns.each do |pattern|
          if message =~ pattern
            group = find_pattern_groups() { |pat| pat == pattern }[0]
            group ||= Logster::Group.new(pattern.inspect)
            group.add_message(message)
            save_pattern_group(group) if group.changed?
            break
          end
        end
      end
      message
    end

    def clear_patterns_cache(key)
      @patterns_cache.clear(key)
    end

    private

    def truncate_message(msg)
      cap = Logster.config.maximum_message_length
      msg.size <= cap ? msg : msg[0...cap] + "..."
    end

    def not_implemented
      raise "Not Implemented"
    end
  end
end

# frozen_string_literal: true

module Logster
  class GroupingPattern < Pattern
    CACHE_KEY = :grouping
    def self.set_name
      "__LOGSTER__grouping_patterns_set".freeze
    end

    def save(args = {})
      super
      group = Logster::Group.new(self.to_s)
      messages = @store.get_all_messages(with_env: false)
      messages.select! { |m| m.message =~ self.pattern }
      group.messages = messages
      @store.save_pattern_group(group) if group.changed?
      @store.clear_patterns_cache(CACHE_KEY)
    end

    def destroy(clear_cache: true) # arg used in tests
      super()
      @store.remove_pattern_group(self.pattern)
      @store.clear_patterns_cache(CACHE_KEY) if clear_cache
    end
  end
end

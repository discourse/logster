# frozen_string_literal: true

module Logster
  class SuppressionPattern < Pattern
    CACHE_KEY = :suppression
    def self.set_name
      "__LOGSTER__suppression_patterns_set".freeze
    end

    def save(args = {})
      super
      @store.clear_patterns_cache(CACHE_KEY)
      retro_delete_messages if args[:retroactive]
    end

    def destroy(clear_cache: true) # arg used in tests
      super()
      @store.remove_ignore_count(self.to_s)
      @store.clear_patterns_cache(CACHE_KEY) if clear_cache
    end

    private

    def retro_delete_messages
      keys = []
      grouping_keys = []
      @store.get_all_messages(with_env: false).each do |message|
        if message =~ self.pattern
          keys << message.key
          grouping_keys << message.grouping_key
        end
      end
      @store.bulk_delete(keys, grouping_keys) if keys.size > 0 && grouping_keys.size > 0
    end
  end
end

module Logster
  class SuppressionPattern < Pattern
    def self.set_name
      "__LOGSTER__suppression_patterns_set".freeze
    end

    def save
      super
      @store.clear_suppression_patterns_cache
    end

    def destroy(clear_cache: true) # arg used in tests
      super()
      @store.remove_ignore_count(self.to_s)
      @store.clear_suppression_patterns_cache if clear_cache
    end
  end
end

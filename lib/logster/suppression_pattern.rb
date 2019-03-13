module Logster
  class SuppressionPattern < Pattern
    def self.set_name
      "__LOGSTER__suppression_patterns_set".freeze
    end
  end
end

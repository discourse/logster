module Logster
  class Configuration
    attr_accessor :current_context, :allow_grouping, :environments,
      :application_version, :web_title, :env_expandable_keys, :enable_custom_patterns_via_ui

    attr_writer :subdirectory

    def initialize
      # lambda |env,block|
      @current_context = lambda { |_, &block| block.call }
      @environments = [:development, :production]
      @subdirectory = nil
      @env_expandable_keys = []
      @enable_custom_patterns_via_ui = false

      @allow_grouping = false

      if defined?(::Rails) && defined?(::Rails.env) && ::Rails.env.production?
        @allow_grouping = true
      end
    end

    def subdirectory
      @subdirectory || '/logs'
    end
  end
end

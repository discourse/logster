# frozen_string_literal: true

module Logster
  class Configuration
    attr_accessor(
      :allow_grouping,
      :application_version,
      :current_context,
      :env_expandable_keys,
      :enable_custom_patterns_via_ui,
      :enable_js_error_reporting,
      :environments,
      :rate_limit_error_reporting,
      :web_title,
      :maximum_message_size_bytes,
      :project_directories,
      :enable_backtrace_links,
      :gems_dir,
      :max_env_bytes,
      :max_env_count_per_message,
      :maximum_message_length
    )

    attr_writer :subdirectory

    def initialize
      # lambda |env,block|
      @current_context = lambda { |_, &block| block.call }
      @environments = [:development, :production]
      @subdirectory = nil
      @env_expandable_keys = []
      @enable_custom_patterns_via_ui = false
      @rate_limit_error_reporting = true
      @enable_js_error_reporting = true
      @maximum_message_size_bytes = 10_000
      @max_env_bytes = 1000
      @max_env_count_per_message = 50
      @project_directories = []
      @enable_backtrace_links = true
      @gems_dir = Gem.dir + "/gems/"
      @maximum_message_length = 2000

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

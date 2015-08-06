module Logster
  class Configuration
    attr_accessor :current_context, :allow_grouping, :environments
    attr_writer :subdirectory

    def initialize
      # lambda |env,block|
      @current_context = lambda{ |_, &block| block.call }
      @environments = [:development, :production]
      @subdirectory = nil

      @allow_grouping = false
      if defined?(::Rails) && ::Rails.env.production?
        @allow_grouping = true
      end
    end

    def subdirectory
      @subdirectory || '/logs'
    end
  end
end

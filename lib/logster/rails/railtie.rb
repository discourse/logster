# frozen_string_literal: true

module Logster::Rails
  # this magically registers logster.js in the asset pipeline
  class Engine < Rails::Engine
  end

  class << self
    def set_logger(config)
      return unless Logster.config.environments.include?(Rails.env.to_sym)

      require "logster/middleware/debug_exceptions"
      require "logster/middleware/reporter"

      store = Logster.store ||= Logster::RedisStore.new
      store.level = Logger::Severity::WARN if Rails.env.production?

      if Rails.env.development?
        require "logster/defer_logger"
        logger = Logster::DeferLogger.new(store)
      else
        logger = Logster::Logger.new(store)
      end

      logger.level = ::Rails.logger.level

      Logster.logger = config.logger = logger

      if rails_71?
        ::Rails.logger.broadcast_to(logger)
      else
        logger.chain(::Rails.logger)
        ::Rails.logger = logger
      end
    end

    def initialize!(app)
      return unless Logster.config.environments.include?(Rails.env.to_sym)
      return unless logster_enabled?

      if Logster.config.enable_js_error_reporting
        app.middleware.insert_before ActionDispatch::ShowExceptions, Logster::Middleware::Reporter
      end

      if Rails::VERSION::MAJOR == 3
        app.middleware.insert_before ActionDispatch::DebugExceptions,
                                     Logster::Middleware::DebugExceptions
      else
        app.middleware.insert_before ActionDispatch::DebugExceptions,
                                     Logster::Middleware::DebugExceptions,
                                     Rails.application
      end

      app.middleware.delete ActionDispatch::DebugExceptions
      app.config.colorize_logging = false

      unless Logster.config.application_version
        git_version = `cd #{Rails.root} && git rev-parse --short HEAD 2> /dev/null`
        Logster.config.application_version = git_version.strip if git_version.present?
      end
    end

    private

    def logster_enabled?
      return ::Rails.logger == Logster.logger unless rails_71?
      ::Rails.logger.broadcasts.include?(Logster.logger)
    end

    def rails_71?
      ::Rails.version >= "7.1"
    end
  end

  class Railtie < ::Rails::Railtie
    config.before_initialize { Logster::Rails.set_logger(config) }

    initializer "logster.configure_rails_initialization" do |app|
      Logster::Rails.initialize!(app)
    end
  end
end

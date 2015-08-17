module Logster::Rails

  # this magically registers logster.js in the asset pipeline
  class Engine < Rails::Engine
  end

  def self.set_logger(config)
    return unless Logster.config.environments.include?(Rails.env.to_sym)

    require 'logster/middleware/debug_exceptions'
    require 'logster/middleware/reporter'

    store = Logster.store ||= Logster::RedisStore.new
    store.level = Logger::Severity::WARN if Rails.env.production?

    logger = Logster::Logger.new(store)
    logger.chain(::Rails.logger)
    logger.level = ::Rails.logger.level

    Logster.logger = ::Rails.logger = config.logger = logger
  end


  def self.initialize!(app)
    return unless Logster.config.environments.include?(Rails.env.to_sym)

    if Logster::Logger === Rails.logger
      app.middleware.insert_before ActionDispatch::ShowExceptions, Logster::Middleware::Reporter

      if Rails::VERSION::MAJOR == 3
        app.middleware.insert_before ActionDispatch::DebugExceptions, Logster::Middleware::DebugExceptions
      else
        app.middleware.insert_before ActionDispatch::DebugExceptions, Logster::Middleware::DebugExceptions, Rails.application
      end

      app.middleware.delete ActionDispatch::DebugExceptions
      app.config.colorize_logging = false

      unless Logster.config.application_version
        git_version = `cd #{Rails.root} && git rev-parse --short HEAD 2> /dev/null`
        if git_version.present?
          Logster.config.application_version = git_version.strip
        end
      end
    end
  end

  class Railtie < ::Rails::Railtie

    config.before_initialize do
      Logster::Rails.set_logger(config)
    end

    initializer "logster.configure_rails_initialization" do |app|
      Logster::Rails.initialize!(app)
    end
  end
end

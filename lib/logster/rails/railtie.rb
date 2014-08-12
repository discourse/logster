module Logster::Rails

  # this magically registers logster.js in the asset pipeline
  class Engine < Rails::Engine
  end

  def self.set_logger(config)
    return unless Rails.env.development? || Rails.env.production?

    if defined?(Redis)
      require 'logster/middleware/debug_exceptions'
      require 'logster/middleware/reporter'
      require 'logster/redis_store'

      store = Logster.store ||= Logster::RedisStore.new
      store.level = Logger::Severity::WARN if Rails.env.production?

      logger = Logster::Logger.new(store)
      logger.chain(::Rails.logger)
      logger.level = ::Rails.logger.level

      Logster.logger = ::Rails.logger = config.logger = logger
    else
      Rails.logger.warn "Not loading logster, Redis missing"
    end
  end


  def self.initialize!(app)
    return unless Rails.env.development? || Rails.env.production?

    if Logster::Logger === Rails.logger
      app.middleware.insert_before ActionDispatch::ShowExceptions, Logster::Middleware::Reporter

      if Rails::VERSION::MAJOR == 3
        app.middleware.insert_before ActionDispatch::DebugExceptions, Logster::Middleware::DebugExceptions
      else
        app.middleware.insert_before ActionDispatch::DebugExceptions, Logster::Middleware::DebugExceptions, Rails.application
      end

      app.middleware.delete ActionDispatch::DebugExceptions
      app.config.colorize_logging = false
    end
  end

  class Railtie < ::Rails::Railtie

    config.before_initialize do
      Logster.config.authorize_callback = lambda {|env|
        Rails.env == "development"
      }
      Logster::Rails.set_logger(config)
    end

    initializer "logster.configure_rails_initialization" do |app|
      Logster::Rails.initialize!(app)
    end
  end
end

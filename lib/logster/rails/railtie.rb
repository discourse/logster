module Logster::Rails

  def self.set_logger(config)
    return unless Rails.env.development?

    if defined?(Redis)
      require 'logster/middleware/viewer'
      require 'logster/redis_store'

      store = Logster::RedisStore.new
      logger = Logster::Logger.new(store)

      ::Rails.logger = config.logger = logger
    else
      Rails.logger.warn "Not loading logster, Redis missing"
    end
  end

  def self.initialize!(app)
    return unless Rails.env.development?

    if Logster::Logger === Rails.logger
      app.middleware.use Logster::Middleware::Viewer, store: Rails.logger.store

      app.config.colorize_logging = false
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

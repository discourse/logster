require 'logster/logger'
require 'logster/message'
require 'logster/configuration'
require 'logster/web'
require 'logster/ignore_pattern'

module Logster
  def self.logger=(logger)
    @logger = logger
  end

  def self.logger
    @logger
  end

  def self.store=(store)
    @store=store
  end

  def self.store
    @store
  end

  def self.config=(config)
    @config = config
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.add_to_env(env, key, value)
    logster_env = Logster::Message.populate_from_env(env)
    logster_env[key] = value
  end
end

Logster.config.current_context = lambda{ |env, &block| block.call }
Logster.config.authorize_callback = lambda{ |env| true }

if defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i >= 3
  require 'logster/rails/railtie'
end

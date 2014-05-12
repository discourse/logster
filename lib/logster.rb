require 'logster/logger'
require 'logster/message'
require 'logster/configuration'

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

if defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i >= 3
  require 'logster/rails/railtie'
end

require 'logster/logger'
require 'logster/message'
require 'logster/configuration'
require 'logster/web'
require 'logster/ignore_pattern'

if defined? Redis
  require 'logster/redis_store'
else
  STDERR.puts "ERROR: Redis is not loaded, ensure redis gem is required before logster"
  exit
end

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

  def self.set_environments(envs)
    config.environments = envs
  end
end

# check logster/configuration.rb for config options
# Logster.config.environments << :staging

if defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i >= 3
  require 'logster/rails/railtie'
end

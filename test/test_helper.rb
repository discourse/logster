require 'minitest'
require 'minitest/unit'
require 'minitest/autorun'
require 'minitest/pride'
require 'logster'
require 'redis'


class Logster::TestStore
  attr_accessor :reported
  def initialize
    @reported = []
  end

  def report(severity, progname, message, opts = nil)
    opts ||= {}
    env = opts[:env]
    backtrace = opts[:backtrace]
    if env && !backtrace
      backtrace = env[:backtrace]
    end

    message = Logster::Message.new(severity, progname, message)

    if backtrace
      message.backtrace = backtrace
    else
      message.backtrace = caller.join("\n")
    end

    if env
      message.populate_from_env(env)
    end

    @reported << message

    message
  end
end

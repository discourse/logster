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
    message = Logster::Message.new(severity, progname, message)

    @reported << message
  end
end

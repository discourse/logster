require 'minitest'
require 'minitest/unit'
require 'minitest/autorun'
require 'minitest/pride'
require 'logster'
require 'redis'


class Logster::TestStore < Logster::BaseStore
  attr_accessor :reported
  def initialize
    @reported = []
  end

  def save(message)
    @reported << message
  end
end

require 'minitest'
require 'minitest/unit'
require 'minitest/autorun'
require 'minitest/pride'
require 'logster'
require 'redis'
require 'logster/base_store'

class Logster::TestStore < Logster::BaseStore
  attr_accessor :reported
  def initialize
    @reported = []
  end

  def save(message)
    @reported << message
  end

  def count
    @reported.count
  end
end

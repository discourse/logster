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

  def report(*args)
    @reported << args
  end
end

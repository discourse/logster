require 'minitest'
require 'minitest/unit'
require 'minitest/autorun'
require 'minitest/pride'
require 'redis'
require 'logster'
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

  def clear
    @reported = []
  end

  def clear_all
    @reported = []
  end

  # get, protect, unprotect: unimplemented
end

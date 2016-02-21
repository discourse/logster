require 'minitest'
require 'minitest/unit'
require 'minitest/autorun'
require 'minitest/pride'
require 'redis'
require 'logster'
require 'logster/base_store'
require 'timecop'

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

  def check_rate_limits(severity)
    # Do nothing
  end

  # get, protect, unprotect: unimplemented
end

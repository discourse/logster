# frozen_string_literal: true

require 'minitest'
require 'minitest/unit'
require 'minitest/autorun'
require 'minitest/pride'
require 'redis'
require 'logster'
require 'logster/base_store'
require 'timecop'
require 'byebug'

class Logster::TestStore < Logster::BaseStore
  attr_accessor :reported
  def initialize
    super
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

  def increment_ignore_count(pattern)
  end

  # get, protect, unprotect: unimplemented
end

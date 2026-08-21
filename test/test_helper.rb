# frozen_string_literal: true

require "minitest"
require "minitest/autorun"
require "minitest/pride"

module StubSupport
  def stub(method_name, value_or_callable = nil, &block)
    original = method(method_name)
    define_singleton_method(method_name) do |*args, &blk|
      value_or_callable.respond_to?(:call) ? value_or_callable.call(*args, &blk) : value_or_callable
    end
    yield self
  ensure
    begin
      singleton_class.undef_method(method_name)
    rescue StandardError
      nil
    end
    begin
      define_singleton_method(method_name, original)
    rescue StandardError
      nil
    end
  end
end

Module.include StubSupport
require "redis"
require "logster"
require "logster/base_store"
require "timecop"
require "debug"

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

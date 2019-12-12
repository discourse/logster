# frozen_string_literal: true

require_relative '../test_helper'
require 'logster/logger'
require 'logger'

class TestStore < Logster::BaseStore
  attr_accessor :calls

  def report(*args)
    (@calls ||= []) << args
  end
end

class TestLogger < Minitest::Test

  def setup
    @store = TestStore.new
    @logger = Logster::Logger.new(@store)
  end

  def test_only_logs_valid_encoding
    @logger.add(4, "a \xE4 test", "prog")
    _, _, message = @store.calls[0]
    assert_equal true, message.valid_encoding?
  end

  def test_per_thread_override
    @logger.override_level = 2

    @logger.add(0, "test", "prog", backtrace: "backtrace", env: { a: "x" })
    Thread.new do
      @logger.add(0, "test", "prog", backtrace: "backtrace", env: { a: "x" })
    end.join

    @logger.override_level = nil
    @logger.add(0, "test", "prog", backtrace: "backtrace", env: { a: "x" })

    assert_equal 2, @store.calls.length
  end

  def test_backtrace
    @logger.add(0, "test", "prog", backtrace: "backtrace", env: { a: "x" })
    assert_equal "backtrace", @store.calls[0][3][:backtrace]
  end

  def test_chain
    io = StringIO.new
    @logger.chain Logger.new(io)
    @logger.warn "boom"

    assert_match(/W,.*boom/, io.string)
  end

  def test_backtrace_with_chain
    @other_store = TestStore.new
    @logger.chain(Logster::Logger.new(@other_store))

    @logger.add(0, "test", "prog", backtrace: "backtrace", env: { a: "x" })

    [@store, @other_store].each do |store|
      assert_equal "backtrace", store.calls[0][3][:backtrace]
    end
  end

  def test_add_with_one_argument
    @logger.add(2) { "test" }
    @logger.add(2)
    assert_equal 2, @store.calls.length
    assert_equal "test", @store.calls.first[2]
  end

  class NewLogger < Logster::Logger; end

  def test_inherited_logger_backtrace_with_chain
    @other_store = TestStore.new
    @logger = NewLogger.new(@store)
    @logger.chain(Logster::Logger.new(@other_store))

    @logger.add(0, "test", "prog", backtrace: "backtrace", env: { a: "x" })

    [@store, @other_store].each do |store|
      assert_equal "backtrace", store.calls[0][3][:backtrace]
    end
  end

  def test_progname_parameter
    @logger.add(0, "test")
    progname = @store.calls[0][1]
    assert_nil progname
  end

  class PlayLogger
    attr_accessor :skip_store
    def initialize(tester)
      @tester = tester
    end

    def add(s, m, p, &block)
      @tester.assert(skip_store)
    end
  end

  def test_chain_with_ignore
    @logger.chain PlayLogger.new(self)
    @logger.skip_store = true
    @logger.warn("testing")
  end
end

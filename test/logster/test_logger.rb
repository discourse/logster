require_relative '../test_helper'
require 'logster/logger'
require 'logger'

class TestStore
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

  def test_backtrace
    @logger.add(0, "test", "prog", backtrace: "backtrace", env: {a: "x"})
    assert_equal "backtrace", @store.calls[0][3][:backtrace]
  end

  def test_chain
    io = StringIO.new
    @logger.chain Logger.new(io)
    @logger.warn "boom"

    assert_match(/W,.*boom/, io.string)
  end

  class PlayLogger
    attr_accessor :skip_store
    def initialize(tester)
      @tester = tester
    end

    def add(s,m,p,&block)
      @tester.assert(skip_store)
    end
  end

  def test_chain_with_ignore
    @logger.chain PlayLogger.new(self)
    @logger.skip_store = true
    @logger.warn("testing")
  end
end

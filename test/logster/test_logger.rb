require_relative '../test_helper'
require 'logster/logger'
require 'logger'

class NullStore
  def report(severity,progname,message,options=nil)
  end
end

class TestLogger < Minitest::Test

  def setup
    @logger = Logster::Logger.new(NullStore.new)
  end

  def teardown
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

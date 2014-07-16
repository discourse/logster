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
end

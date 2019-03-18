require_relative '../test_helper'
require 'logster/cache'

class TestCache < Minitest::Test
  def setup
    @cache = Logster::Cache.new(5)
  end

  def test_cache_works
    value = "I should be retured"
    prc = Proc.new do 
      @cache.fetch do
        value
      end
    end
    assert_equal(value, prc.call)
    cached_value = value
    value = "I shouldn't be returned"
    assert_equal(cached_value, prc.call)

    value = "Now I should be returned again"
    Process.stub :clock_gettime,  Process.clock_gettime(Process::CLOCK_MONOTONIC) + 6 do
      assert_equal(value, prc.call)
    end
  end

  def test_cache_can_be_cleared
    value = "cached"
    prc = Proc.new do
      @cache.fetch { value }
    end
    assert_equal(value, prc.call)

    value = "new value"
    @cache.clear
    assert_equal(value, prc.call)
  end
end

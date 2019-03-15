require_relative '../test_helper'
require 'logster/cache'

class TestCache < Minitest::Test
  def setup
    @cache = Logster::Cache.new(5)
  end

  def test_cache_works
    value = "I should be retured"
    prc = Proc.new do 
      @cache.get do
        value
      end
    end
    assert_equal(value, prc.call)
    cached_value = value
    value = "I shouldn't be returned"
    assert_equal(cached_value, prc.call)

    value = "Now I should be returned again"
    Time.stub :now, Time.at(Time.now + 6) do
      assert_equal(value, prc.call)
    end
  end
end

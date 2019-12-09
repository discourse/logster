# frozen_string_literal: true

require_relative '../test_helper'
require 'logster/cache'

class TestCache < Minitest::Test
  def setup
    @cache = Logster::Cache.new(5)
  end

  def test_cache_works
    prc = Proc.new do |key, value|
      @cache.fetch(key) do
        value
      end
    end
    value = "I should be retured"
    assert_equal(value, prc.call(:key1, value))
    cached_value = value
    value = "I shouldn't be returned"
    assert_equal(cached_value, prc.call(:key1, value))
    value2 = "value for key2"
    assert_equal(value2, prc.call(:key2, value2))

    value = value2 = "Now I should be returned"
    Process.stub :clock_gettime,  Process.clock_gettime(Process::CLOCK_MONOTONIC) + 6 do
      assert_equal(value, prc.call(:key1, value))
      assert_equal(value2, prc.call(:key2, value2))
    end
  end

  def test_cache_can_be_cleared
    value = "cached"
    prc = Proc.new do |key, val|
      @cache.fetch(key) { val }
    end
    assert_equal(value, prc.call(:key1, value))
    assert_equal("v2", prc.call(:key2, "v2"))

    value = "new value"
    @cache.clear(:key1)
    assert_equal(value, prc.call(:key1, value))
    assert_equal("v2", prc.call(:key2, "v2.2"))
  end
end

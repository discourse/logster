# frozen_string_literal: true

require_relative '../test_helper'
require 'logster/redis_store'
require 'logster/pattern'

class TestPattern < Minitest::Test
  class FakePattern < Logster::Pattern
    def self.set_name
      "__LOGSTER__fake_patterns_set".freeze
    end
  end

  class TestRedisStore < Logster::BaseStore
    def get_patterns(set_name)
      ["/differentstore/"]
    end
  end

  def setup
    Logster.store = Logster::RedisStore.new
    Logster.store.clear_all
  end

  def teardown
    Logster.store.clear_all
    Logster.store = nil
  end

  def test_parse_pattern_works_correctly
    assert_equal(/osama/i, klass.parse_pattern(/osama/i))
    assert_equal(/osama/i, klass.parse_pattern("/osama/i"))
    assert_equal(/osama/, klass.parse_pattern("/osama/"))
    assert_equal(/osama/, klass.parse_pattern("osama"))
    assert_equal(/[a-zA-Z]/, klass.parse_pattern("[a-zA-Z]"))
    assert_equal(/[a-zA-Z]/, klass.parse_pattern("/[a-zA-Z]/"))

    assert_nil(klass.parse_pattern("/osama"))
    assert_nil(klass.parse_pattern("["))
    assert_nil(klass.parse_pattern("/[/"))
  end

  def test_validity_checks_are_correct
    assert(klass.valid?(/osama/))
    refute(klass.valid?(//))
    refute(klass.valid?(//i))
    refute(klass.valid?(/ /))
  end

  def test_find_all_works_correctly
    patterns = ["/test/i", "tttt", "[d-y].*"]
    patterns.each { |p| FakePattern.new(p).save }

    results = FakePattern.find_all
    assert_equal(3, results.size)
    assert_includes(results, /test/i)
    assert_includes(results, /tttt/)
    assert_includes(results, /[d-y].*/)

    results = FakePattern.find_all(raw: true)
    assert_equal(3, results.size)
    assert_includes(results, "/test/i")
    assert_includes(results, "/tttt/")
    assert_includes(results, "/[d-y].*/")
  end

  def test_find_all_can_take_an_instance_of_store
    results = FakePattern.find_all(store: TestRedisStore.new)
    assert_equal(1, results.size)
    assert_equal(/differentstore/, results.first)
  end

  def test_find_works_correctly
    FakePattern.new("/wwwlll/").save

    record = FakePattern.find("wwwlll")
    assert_equal(/wwwlll/, record.pattern)
    record = FakePattern.find(/wwwlll/)
    assert_equal(/wwwlll/, record.pattern)

    assert_nil(FakePattern.find("dfsdfsdf"))
    assert_nil(FakePattern.find(nil))
  end

  def test_patterns_get_parsed_on_initialize
    assert_equal(/mypattern/, FakePattern.new("mypattern").pattern)
    assert_equal(/111333/, FakePattern.new(/111333/).pattern)
  end

  def test_save_works_correctly
    bad_patterns = ["/bruken", nil, "[a-z", "/(osa|sss{1/"]
    bad_patterns.each do |p|
      assert_raises(Logster::Pattern::PatternError) do
        FakePattern.new(p).save
      end
    end
    assert_equal(0, FakePattern.find_all.size)

    good_patterns = ["/logster/i", /logster/, "sssd", "(ccx|tqe){1,5}", "logster"]
    good_patterns.each do |p|
      FakePattern.new(p).save
    end
    results = FakePattern.find_all
    assert_equal(4, results.size) # 4 because /logster/ and logster are the same
    good_patterns_regex = [/logster/i, /logster/, /sssd/, /(ccx|tqe){1,5}/]
    results.each do |p|
      assert_includes(good_patterns_regex, p)
    end
  end

  def test_modify_works_correctly
    record = FakePattern.new(/logster/)
    record.save

    record.modify("/LoGsTEr/")
    all_patterns = FakePattern.find_all
    assert_equal(1, all_patterns.size)
    assert_equal(/LoGsTEr/, all_patterns.first)
    assert_equal(/LoGsTEr/, record.pattern)
  end

  def test_modify_doesnt_remove_old_pattern_when_new_is_bad
    record = FakePattern.new(/LoGsTEr/)
    record.save

    assert_raises(Logster::Pattern::PatternError) do
      record.modify("/badReg")
    end
    all_patterns = FakePattern.find_all
    assert_equal(1, all_patterns.size)
    assert_equal(/LoGsTEr/, all_patterns.first)
    assert_equal(/LoGsTEr/, record.pattern)
  end

  def test_destroy_works_correctly
    record = FakePattern.new(/somepattern/)
    record.save

    patterns = FakePattern.find_all
    assert_equal(1, patterns.size)
    assert_equal(/somepattern/, patterns.first)

    record.destroy
    assert_equal(0, FakePattern.find_all.size)
  end

  private

  def klass
    Logster::Pattern
  end
end

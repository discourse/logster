require_relative '../test_helper'
require 'logster/message'

class TestMessage < MiniTest::Test

  def test_merge_similar
    msg1 = Logster::Message.new(0, '', 'test', 10)
    msg1.populate_from_env(a: "1", b: "2")

    msg2 = Logster::Message.new(0, '', 'test', 20)
    msg2.populate_from_env(a: "2", c: "3")

    assert_equal(msg2.grouping_key, msg1.grouping_key)

    msg1.merge_similar_message(msg2)

    msg1 = Logster::Message.from_json(msg1.to_json)

    assert_equal(20, msg1.timestamp)
    assert_equal(10, msg1.first_timestamp)

    assert Array === msg1.env
    assert_equal(msg1.env.size, 2)
    assert({ "a" => "1", "b" => "2" } <= msg1.env[0])
    assert({ "a" => "2", "c" => "3" } <= msg1.env[1])
  end

  def test_merge_messages_both_with_array_envs
    msg1 = Logster::Message.new(0, '', 'test', 10)
    msg1.env = [{ a: "aa", b: "bb" }, { c: "cc", d: "dd" }]

    msg2 = Logster::Message.new(0, '', 'test', 20)
    msg2.env = [{ e: "ee", f: "ff" }, { g: "gg", h: "hh" }]

    msg1.merge_similar_message(msg2) 
    msg1 = Logster::Message.from_json(msg1.to_json)

    # new env should be an array, but it should never have
    # another array of envs within itself (hence flatten(1))
    assert_equal(msg1.env.size, 4)
    assert_equal(msg1.env.map(&:keys).flatten(1), %w{a b c d e f g h})
    assert_equal(msg1.env.map(&:values).flatten(1), %w{aa bb cc dd ee ff gg hh})
  end

  def test_merge_messages_one_with_array_envs
    msg1 = Logster::Message.new(0, '', 'test', 10)
    msg1.env = [{ a: "aa", b: "bb" }, { c: "cc", d: "dd" }]

    msg2 = Logster::Message.new(0, '', 'test', 20)
    msg2.env = { e: "ee", f: "ff" }

    msg1.merge_similar_message(msg2) 
    msg1 = Logster::Message.from_json(msg1.to_json)

    assert_equal(msg1.env.size, 3)
    assert_equal(msg1.env.map(&:keys).flatten(1), %w{a b c d e f})
    assert_equal(msg1.env.map(&:values).flatten(1), %w{aa bb cc dd ee ff})
  end

  def test_adds_application_version
    Logster.config.application_version = "abc"
    msg = Logster::Message.new(0, '', 'test', 10)
    msg.populate_from_env({})

    assert_equal("abc", msg.env["application_version"])

  ensure
    Logster.config.application_version = nil
  end

  def test_merging_sums_count_for_both_messages
    msg1 = Logster::Message.new(0, '', 'test', 10, count: 15)
    msg2 = Logster::Message.new(0, '', 'test', 20, count: 13)
    msg2.env = {}

    assert_equal(msg1.grouping_key, msg2.grouping_key)

    msg1.merge_similar_message(msg2)
    msg1 = Logster::Message.from_json(msg1.to_json)
    assert_equal(msg1.count, 15 + 13)
  end

  def test_populate_from_env_works_on_array
    msg = Logster::Message.new(0, '', 'test', 10)
    hash = { "custom_key" => "key" }
    msg.populate_from_env([hash])

    msg = Logster::Message.from_json(msg.to_json)
    assert Array === msg.env
    assert_equal(msg.env.size, 1)
    assert hash <= msg.env[0]
  end
end

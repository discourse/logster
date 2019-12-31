# frozen_string_literal: true

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

    assert_equal(20, msg1.timestamp)
    assert_equal(10, msg1.first_timestamp)

    assert Array === msg1.env
    assert_equal(msg1.env.size, 2)
    assert({ a: "2", c: "3" } <= msg1.env[0])
    assert({ a: "1", b: "2" } <= msg1.env[1])
  end

  def test_merge_adds_timestamp_to_env
    time1 = Time.new(2010, 1, 1, 1, 1).to_i
    msg1 = Logster::Message.new(0, '', 'test', time1)
    msg1.env = { a: "aa", b: "bb" }

    time2 = Time.new(2011, 1, 1, 1, 1).to_i
    msg2 = Logster::Message.new(0, '', 'test', time2)
    msg2.env = { e: "ee", f: "ff" }

    msg1.merge_similar_message(msg2)
    assert_equal(time2, msg1.env[0]["time"])
    assert_equal(time1, msg1.env[1]["time"])
  end

  def test_merge_messages_both_with_array_envs
    msg1 = Logster::Message.new(0, '', 'test', 10)
    msg1.env = [{ a: "aa", b: "bb" }, { c: "cc", d: "dd" }]

    msg2 = Logster::Message.new(0, '', 'test', 20)
    msg2.env = [{ e: "ee", f: "ff" }, { g: "gg", h: "hh" }]

    msg1.merge_similar_message(msg2)

    # new env should be an array, but it should never have
    # another array of envs within itself (hence flatten(1))
    assert_equal(msg1.env.size, 4)
    assert_equal(msg1.env.map(&:keys).flatten(1).map(&:to_s).sort, %w{a b c d e f g h})
    assert_equal(msg1.env.map(&:values).flatten(1).map(&:to_s).sort, %w{aa bb cc dd ee ff gg hh})
  end

  def test_merge_messages_one_with_array_envs
    msg1 = Logster::Message.new(0, '', 'test', 10)
    msg1.env = [{ a: "aa", b: "bb" }, { c: "cc", d: "dd" }]

    msg2 = Logster::Message.new(0, '', 'test', 20)
    msg2.env = { e: "ee", f: "ff" }

    msg1.merge_similar_message(msg2)

    assert_equal(msg1.env.size, 3)
    assert_equal(msg1.env.map(&:keys).flatten(1).map(&:to_s).sort, %w{a b c d e f time})
    assert_equal(msg1.env.map(&:values).flatten(1).map(&:to_s).sort, %w{aa bb cc dd ee ff 20}.sort)
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

    save_env = msg1.merge_similar_message(msg2)
    assert(save_env)
    assert_equal(msg1.count, 15 + 13)
  end

  def test_messages_with_bad_encoding_dont_break_logster
    hash = {
      severity: 0,
      progname: "test",
      message: "invalid encoding",
      env: {
        a: "bad_value",
        b: ["bad_value"]
      }
    }
    json = hash.to_json.gsub("bad_value", "45\xC0\xBE")
    message = Logster::Message.from_json(json)
    message.to_json # test failure would be this raising exception

    message.env = JSON.parse(json)["env"]
    message.to_json
  end

  def test_populate_from_env_works_on_array
    msg = Logster::Message.new(0, '', 'test', 10)
    hash = { "custom_key" => "key" }
    msg.populate_from_env([hash])

    assert Array === msg.env
    assert_equal(msg.env.size, 1)
    assert hash <= msg.env[0]
  end

  def test_ensure_env_samples_dont_exceed_50_when_merging_2_env_arrays
    msg1 = Logster::Message.new(0, '', 'test', 10, count: 50)
    env_1 = 50.times.map { |n| { a: n } }
    msg1.env = env_1.dup
    msg2 = Logster::Message.new(0, '', 'test', 20, count: 13)
    env_2 = 13.times.map { |n| { b: n } }
    msg2.env = env_2.dup

    assert_equal(msg1.grouping_key, msg2.grouping_key)

    msg1.merge_similar_message(msg2)
    assert_equal(63, msg1.count) # update count
    # 50 - 13 = 37
    # add the env of msg2 to the front, and eat from the rear
    # of msg1 env to keep the env total at 50 items
    assert_equal(env_2 + env_1.first(37), msg1.env)
    assert_equal(50, msg1.env.size)
  end

  def test_message_to_h_respects_params
    msg = Logster::Message.new(0, "", "test")
    test_hash = { test_key: "this is a test" }
    msg.env = test_hash
    assert_equal(test_hash, msg.to_h[:env])
    assert_nil(msg.to_h(exclude_env: true)[:env])
  end

  def test_message_to_json_respects_params
    msg = Logster::Message.new(0, "", "test")
    test_hash = { test_key: "this is a test" }
    msg.env = test_hash
    assert_includes(msg.to_json, test_hash.to_json)
    refute_includes(msg.to_json(exclude_env: true), test_hash.to_json)
  end

  def test_title_is_truncated_when_too_large
    msg = Logster::Message.new(0, "", "a" * 1000)
    # 3 is the ... at the end to indicate truncated message
    assert_equal(600 + 3, msg.message.size)
  end

  def test_env_is_not_merged_into_similar_message_if_size_will_be_too_large
    default = Logster.config.maximum_message_size_bytes
    Logster.config.maximum_message_size_bytes = 1000
    message = Logster::Message.new(Logger::INFO, "test", "message", count: 13)
    env = [{ key1: "this is my first key", key2: "this is my second key" }] * 13
    message.env = env

    message2 = Logster::Message.new(Logger::INFO, "test", "message")
    message2.env = env.first
    message.merge_similar_message(message2)

    # env isn't merged, but count is incremented
    assert_equal(13, message.env.size)
    assert_equal(14, message.count)
  ensure
    Logster.config.maximum_message_size_bytes = default
  end
end

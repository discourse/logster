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
    assert_equal(msg1.env_buffer, [msg2.env])
  end

  def test_populate_from_env_will_add_time_to_env_unless_it_already_exists
    t = (Time.now.to_f * 1000).to_i
    msg = Logster::Message.new(0, '', 'test', t)
    msg.populate_from_env({})
    assert_equal(t, msg.env["time"])

    msg = Logster::Message.new(0, '', 'test', t)
    msg.populate_from_env(time: 5)
    assert_nil(msg.env["time"])
    assert_equal(5, msg.env[:time])

    msg = Logster::Message.new(0, '', 'test', t)
    msg.populate_from_env("time" => 6)
    assert_equal(6, msg.env["time"])
    assert_nil(msg.env[:time])

    msg = Logster::Message.new(0, '', 'test', t)
    msg.populate_from_env([{ "time" => 6 }, { "time" => 8 }])
    assert_equal([6, 8], msg.env.map { |e| e["time"] })
    assert_equal([nil, nil], msg.env.map { |e| e[:time] })

    msg = Logster::Message.new(0, '', 'test', t)
    msg.populate_from_env([{ dsd: 6 }, { dsd: 8 }])
    assert_equal([t, t], msg.env.map { |e| e["time"] })
  end

  def test_merge_messages_both_with_array_envs
    msg1 = Logster::Message.new(0, '', 'test', 10)
    msg1.env = [{ a: "aa", b: "bb" }, { c: "cc", d: "dd" }]

    msg2 = Logster::Message.new(0, '', 'test', 20)
    msg2.env = [{ e: "ee", f: "ff" }, { g: "gg", h: "hh" }]

    msg1.merge_similar_message(msg2)
    assert_equal(msg2.env, msg1.env_buffer)
  end

  def test_merge_messages_one_with_array_envs
    msg1 = Logster::Message.new(0, '', 'test', 10)
    msg1.env = { e: "ee", f: "ff" }

    msg2 = Logster::Message.new(0, '', 'test', 20)
    msg2.env = [{ a: "aa", b: "bb" }, { c: "cc", d: "dd" }]

    msg1.merge_similar_message(msg2)
    assert_equal(msg2.env, msg1.env_buffer)
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

  def test_merging_envs_add_new_envs_to_buffer
    msg1 = Logster::Message.new(0, '', 'test', 10, count: 50)
    msg1.env = 50.times.map { |n| { a: n } }
    msg2 = Logster::Message.new(0, '', 'test', 20, count: 13)
    msg2.env = 13.times.map { |n| { b: n } }

    assert_equal(msg1.grouping_key, msg2.grouping_key)

    msg1.merge_similar_message(msg2)
    assert_equal(63, msg1.count) # update count
    assert_equal(msg2.env, msg1.env_buffer)
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

  def test_drop_redundant_envs
    message = Logster::Message.new(Logger::WARN, '', 'message')
    message.env = [{ a: 4 }] * 10
    assert_equal(10, message.env.size)
    message.drop_redundant_envs(5)
    assert_equal(5, message.env.size)

    env = { f: 5, g: 4 }
    message.env = env.dup
    message.drop_redundant_envs(1)
    assert_equal(env, message.env)
  end

  def test_apply_env_size_limit_keeps_as_many_keys_as_possible
    message = Logster::Message.new(Logger::WARN, '', 'message', 1)
    env = { a: 1, bb: 22, ccc: 333 }
    message.env = env.dup
    message.apply_env_size_limit(24)
    assert_operator(message.env.to_json.bytesize, :<=, 24)
    assert_equal({ a: 1, bb: 22 }.to_json.bytesize, message.env.to_json.bytesize)

    message.env = [env.dup] * 5
    message.apply_env_size_limit(24)
    assert_equal(5, message.env.size)
    message.env.each do |e|
      assert_operator(e.to_json.bytesize, :<=, 24)
      assert_equal({ a: 1, bb: 22 }.to_json.bytesize, e.to_json.bytesize)
    end

    message.env = env.dup
    message.apply_env_size_limit(25)
    assert_operator(message.env.to_json.bytesize, :<=, 25)
    assert_equal({ a: 1, bb: 22, ccc: 333 }.to_json.bytesize, message.env.to_json.bytesize)
  end

  def test_apply_message_size_limit_removes_gems_dir_from_backtrace_to_keep_total_message_size_below_limit
    backtrace = <<~TEXT
      /var/www/discourse/vendor/bundle/ruby/2.6.0/gems/rails_multisite-2.0.7/lib/rails_multisite/connection_management.rb:220:in `with_connection'
      /var/www/discourse/vendor/bundle/ruby/2.6.0/gems/rails_multisite-2.0.7/lib/rails_multisite/connection_management.rb:60:in `with_connection'
      /var/www/discourse/lib/scheduler/defer.rb:89:in `do_work'
      /var/www/discourse/lib/scheduler/defer.rb:79:in `block (2 levels) in start_thread'
    TEXT
    without_gems_dir = <<~TEXT
      rails_multisite-2.0.7/lib/rails_multisite/connection_management.rb:220:in `with_connection'
      rails_multisite-2.0.7/lib/rails_multisite/connection_management.rb:60:in `with_connection'
      /var/www/discourse/lib/scheduler/defer.rb:89:in `do_work'
      /var/www/discourse/lib/scheduler/defer.rb:79:in `block (2 levels) in start_thread'
    TEXT
    gems_dir = "/var/www/discourse/vendor/bundle/ruby/2.6.0/gems/"
    message = Logster::Message.new(Logger::WARN, '', 'message', 1)

    message.backtrace = backtrace.dup
    assert_operator(message.to_json(exclude_env: true).bytesize, :>=, 500)
    message.apply_message_size_limit(500, gems_dir: gems_dir)
    assert_operator(message.to_json(exclude_env: true).bytesize, :<=, 500)
    assert_equal(without_gems_dir.strip, message.backtrace.strip)
  end

  def test_apply_message_size_limit_removes_lines_from_backtrace_to_keep_total_size_below_limit
    backtrace = <<~TEXT
      rails_multisite-2.0.7/lib/rails_multisite/connection_management.rb:220:in `with_connection'
      rails_multisite-2.0.7/lib/rails_multisite/connection_management.rb:60:in `with_connection'
      /var/www/discourse/lib/scheduler/defer.rb:89:in `do_work'
      /var/www/discourse/lib/scheduler/defer.rb:79:in `block (2 levels) in start_thread'
    TEXT

    expected = <<~TEXT
      rails_multisite-2.0.7/lib/rails_multisite/connection_management.rb:220:in `with_connection'
      rails_multisite-2.0.7/lib/rails_multisite/connection_management.rb:60:in `with_connection'
      /var/www/discourse
    TEXT
    message = Logster::Message.new(Logger::WARN, '', 'message', 1)
    message.backtrace = backtrace.dup
    assert_operator(message.to_json(exclude_env: true).bytesize, :>=, 350)
    message.apply_message_size_limit(350)
    assert_operator(message.to_json(exclude_env: true).bytesize, :<=, 350)
    assert_equal(expected.strip, message.backtrace.strip)
  end

  def test_truncate_backtrace_shouldnt_corrupt_backtrace_when_it_contains_multibytes_characters
    backtrace = "aहa"
    message = Logster::Message.new(Logger::WARN, '', 'message', 1)
    message.backtrace = backtrace.dup
    message.truncate_backtrace(3)
    assert_equal("a", message.backtrace)

    message.backtrace = backtrace.dup
    message.truncate_backtrace(4)
    assert_equal("aह", message.backtrace)

    message.backtrace = backtrace.dup
    message.truncate_backtrace(5)
    assert_equal(backtrace, message.backtrace)
  end

  def test_apply_message_size_limit_doesnt_remove_backtrace_entirely
    message = Logster::Message.new(Logger::WARN, '', 'message', 1)
    message.backtrace = "a" * 1000
    assert_operator(message.to_json(exclude_env: true).bytesize, :>=, 500)
    message.apply_message_size_limit(500)
    assert_operator(message.to_json(exclude_env: true).bytesize, :<=, 500)
    assert_equal(("a" * 354).size, message.backtrace.size)
  end

  def test_apply_message_size_limit_doesnt_hang_forever_and_doesnt_remove_backtrace_entirely
    message = Logster::Message.new(Logger::WARN, '', 'message', 1)
    message.backtrace = "aa" * 100
    message.apply_message_size_limit(10)
    assert_equal(("aa" * 100).size, message.backtrace.size)
  end
end

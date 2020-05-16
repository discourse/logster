# frozen_string_literal: true

require_relative '../test_helper'
require 'logster/redis_store'
require 'rack'

class TestRedisStore < Minitest::Test

  def setup
    @store = Logster::RedisStore.new(Redis.new)
    @store.clear_all
  end

  def teardown
    @store.clear_all
  end

  def test_delete
    env = { test_env: "this is env" }
    msg = @store.report(Logger::WARN, "test", "testing", env: env)
    @store.delete(msg)
    latest = @store.latest

    assert_equal(0, latest.length)
    assert_nil(@store.get_env(msg.key))
  end

  def test_delete_with_custom_grouping_patterns
    Logster.config.enable_custom_patterns_via_ui = true
    Logster::GroupingPattern.new(/delete/, store: @store).save
    msg1 = @store.report(Logger::WARN, '', 'this will be deleted')
    msg2 = @store.report(Logger::WARN, '', 'delete this plz')

    groups = @store.find_pattern_groups
    assert_equal 1, groups.size
    assert_equal [msg2.key, msg1.key], groups[0].messages_keys

    @store.delete(msg1)
    groups = @store.find_pattern_groups
    assert_equal 1, groups.size
    assert_equal [msg2.key], groups[0].messages_keys

    @store.delete(msg2)
    groups = @store.find_pattern_groups
    assert_equal 0, groups.size
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_bulk_delete_with_custom_grouping_patterns
    Logster.config.enable_custom_patterns_via_ui = true
    Logster::GroupingPattern.new(/delete/, store: @store).save
    keys = []
    gkeys = []
    6.times do |n|
      m = @store.report(Logger::WARN, '', "#{n} delete")
      keys << m.key
      gkeys << m.grouping_key
    end

    groups = @store.find_pattern_groups
    assert_equal 1, groups.size
    assert_equal keys.reverse, groups[0].messages_keys

    @store.bulk_delete(keys[0..2], gkeys[0..2])
    groups = @store.find_pattern_groups
    assert_equal 1, groups.size
    assert_equal keys[3..5].reverse, groups[0].messages_keys

    @store.bulk_delete(keys, gkeys)
    groups = @store.find_pattern_groups
    assert_equal 0, groups.size
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_latest
    @store.report(Logger::WARN, "test", "IGNORE")
    @store.report(Logger::WARN, "test", "This is a warning")
    @store.report(Logger::WARN, "test", "This is another warning")

    latest = @store.latest(limit: 2)

    assert_equal(2, latest.length)
    assert_equal("This is a warning", latest[0].message)
    assert_equal("This is another warning", latest[1].message)
    assert_equal(Logger::WARN, latest[1].severity)
    assert_equal("test", latest[1].progname)
    assert(!latest[1].key.nil?)
  end

  def test_latest_after
    10.times do |i|
      @store.report(Logger::WARN, "test", "A#{i}")
    end

    message = @store.latest[-1]

    3.times do |i|
      @store.report(Logger::WARN, "test", i.to_s)
    end

    message = @store.latest(after: message.key, limit: 3)[0]

    assert_equal("0", message.message)
  end

  def test_latest_before
    10.times do
      @store.report(Logger::WARN, "test", "A")
    end
    10.times do
      @store.report(Logger::WARN, "test", "B")
    end
    10.times do
      @store.report(Logger::WARN, "test", "C")
    end

    messages = @store.latest(limit: 10)
    assert_equal("C", messages[0].message)
    assert_equal(10, messages.length)

    messages = @store.latest(limit: 10, before: messages[0].key)
    assert_equal("B", messages[0].message)
    assert_equal(10, messages.length)

    messages = @store.latest(limit: 10, before: messages[0].key)
    assert_equal("A", messages[0].message)
    assert_equal(10, messages.length)
  end

  def test_latest_with_custom_grouping
    Logster.config.enable_custom_patterns_via_ui = true
    Logster::GroupingPattern.new(/group 1/, store: @store).save
    Logster::GroupingPattern.new(/group 2/, store: @store).save
    msg1 = @store.report(Logger::WARN, '', 'first message')
    group_1_keys = []
    3.times { |n| group_1_keys << @store.report(Logger::WARN, '', "group 1 #{n}").key }
    msg2 = @store.report(Logger::WARN, '', 'second message')
    group_1_keys << @store.report(Logger::WARN, '', "group 1 3").key
    msg3 = @store.report(Logger::WARN, '', 'third message')
    group_2_keys = []
    3.times { |n| group_2_keys << @store.report(Logger::WARN, '', "group 2 #{n}").key }
    msg4 = @store.report(Logger::WARN, '', 'fourth message')

    results = @store.latest
    assert_equal [msg1.key, msg2.key, "/group 1/", msg3.key, "/group 2/", msg4.key], results.map(&:key)
    groups = results.select { |r| r.class == Logster::Group::GroupWeb }
    assert_equal(
      [group_1_keys.last, group_2_keys.last],
      groups.map(&:row_id)
    )
    assert_equal 4, groups[0].messages.size
    assert_equal 3, groups[1].messages.size

    results = @store.latest(before: groups[0].row_id, known_groups: groups.map(&:key))
    assert_equal [msg1.key, msg2.key], results.map(&:key)

    results = @store.latest(before: groups[1].row_id, known_groups: [groups[1].key])
    assert_equal [msg1.key, msg2.key, "/group 1/", msg3.key], results.map(&:key)

    results = @store.latest(before: msg2.key, known_groups: groups.map(&:key))
    assert_equal [msg1.key], results.map(&:key)

    results = @store.latest(after: groups[0].row_id)
    assert_equal [msg3.key, "/group 2/", msg4.key], results.map(&:key)

    results = @store.latest(after: msg2.key)
    assert_equal ["/group 1/", msg3.key, "/group 2/", msg4.key], results.map(&:key)
    assert_equal 4, results[0].messages.size

    results = @store.latest(after: msg4.key)
    assert_equal 0, results.size

    group_2_keys << @store.report(Logger::WARN, '', "group 2 3").key
    results = @store.latest(after: msg4.key)
    assert_equal ["/group 2/"], results.map(&:key)
    assert_equal group_2_keys.last, results[0].row_id
    assert_equal 4, results[0].messages.size
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_get
    a_env = { "a_message" => "A MESSAGE" }
    a_message = @store.report(Logger::WARN, "test", "A", env: a_env)
    b_message = @store.report(Logger::WARN, "test", "B")
    @store.report(Logger::WARN, "test", "C")

    a_message = @store.get(a_message.key)
    assert_equal("A", a_message.message)
    assert_equal("B", b_message.message)
    assert(a_env <= a_message.env)

    a_message = @store.get(a_message.key, load_env: false)
    assert_equal("A", a_message.message)
    assert_nil(a_message.env)
  end

  def test_save_saves_env_separately
    env = { "myenv" => "thisisenv" }
    message = @store.report(Logger::WARN, "test", "title", env: env)
    message = @store.get(message.key, load_env: false)
    assert_nil(message.env)

    message = @store.get(message.key)
    assert(env <= message.env)

    assert(env <= @store.get_env(message.key))
  end

  def test_bulk_get
    keys = []

    5.times do |n|
      env = n == 0 ? nil : { "test_#{n}" => "envsss" }
      keys << @store.report(Logger::WARN, "progname", "test_#{n}", env: env).key
    end

    messages = @store.bulk_get(keys)

    5.times do |n|
      msg = messages[n]
      assert_equal("test_#{n}", msg.message)
      if n == 0
        assert_equal(Logster::Message.default_env.merge("time" => msg.timestamp), msg.env)
      else
        assert({ "test_#{n}" => "envsss" } <= msg.env)
      end
      assert_equal(msg.timestamp, msg.env["time"])
    end
  end

  def test_get_env
    env = { "my_little_env" => "some value" }
    message = @store.report(Logger::WARN, "test", "A", env: env)
    assert(env <= @store.get_env(message.key))
    assert_nil(@store.get_env("nonexistentkey"))
  end

  def test_replace_and_bump
    old_env = { "old_env" => "old value" }
    message = @store.report(Logger::WARN, "test", "A", env: old_env)

    extra_env = { "saved_env" => "saved value!" }
    similar = @store.report(Logger::WARN, 'test', 'A', env: extra_env)
    message.merge_similar_message(similar)

    @store.replace_and_bump(message)

    message = @store.get(message.key)
    assert(extra_env <= message.env[0])
    assert(old_env <= message.env[1])
  end

  def test_ensure_env_doesnt_exceed_50_item
    Logster.config.allow_grouping = true
    message = nil
    52.times do |n|
      message = @store.report(Logger::WARN, "", "mssage", env: { a: n })
    end
    message = @store.get(message.key)
    assert_equal(52, message.count)
    assert_equal(50, message.env.size)
    assert_equal((2..51).to_a, message.env.map { |e| e[:a] || e["a"] }.sort)
  ensure
    Logster.config.allow_grouping = false
  end

  def test_merging_performance
    Logster.config.allow_grouping = true
    backtrace = "fake backtrace"
    env = [{ "some_env" => "some env" }] * 50
    new_env = { "some_key" => "1234442" }

    @store.report(Logger::WARN, "", "title", backtrace: backtrace, env: env, count: 50)

    message = @store.report(Logger::WARN, "", "title", backtrace: backtrace, env: new_env)
    # env is nil cause we don't need to fetch it from redis
    # we just send the newly added envs to redis and it'll
    # take care of prepending them to the existing envs
    assert_nil(message.env)

    message = @store.get(message.key)
    assert_instance_of(Array, message.env)
    assert_equal(50, message.env.size)
    assert_equal(51, message.count)
    assert(new_env <= message.env[0])
  ensure
    Logster.config.allow_grouping = false
  end

  def test_backlog
    env = { "backlog_test" => "BACKLOG" }
    @store.max_backlog = 1
    deleted_msg = @store.report(Logger::WARN, "test", "A")
    @store.report(Logger::WARN, "test", "A")
    @store.report(Logger::WARN, "test", "A")
    @store.report(Logger::WARN, "test", "B", env: env)

    latest = @store.latest

    assert_equal(1, latest.length)
    assert_equal("B", latest[0].message)
    assert(env <= latest[0].env)
    assert_nil(@store.get(deleted_msg.key))
    assert_nil(@store.get_env(deleted_msg.key))
  end

  def test_save_unsave
    @store.max_backlog = 3
    @store.report(Logger::WARN, "test", "A")
    b_message = @store.report(Logger::WARN, "test", "B")
    @store.protect b_message.key
    c_message = @store.report(Logger::WARN, "test", "C")
    @store.protect c_message.key
    @store.report(Logger::WARN, "test", "D")

    latest = @store.latest

    assert_equal(3, latest.length)
    assert_equal("B", latest[0].message)
    assert_equal("C", latest[1].message)
    assert_equal(true, latest[1].protected)
    assert_equal("D", latest[2].message)

    # Saved messages still accessible by key
    assert_equal("B", @store.get(b_message.key).message)
    assert_equal(true, @store.get(b_message.key).protected)

    # Unsave does not delete message if still recent
    @store.unprotect c_message.key
    assert_equal("C", @store.get(c_message.key).message)
    assert_equal(false, @store.get(c_message.key).protected)
  end

  def test_clear
    env = { "clear_env" => "cllleear" }
    @store.max_backlog = 25
    a_message = @store.report(Logger::WARN, "test", "A", timestamp: Time.now - (24 * 60 * 60), env: env)
    @store.protect a_message.key
    20.times do
      @store.report(Logger::WARN, "test", "B", env: env)
    end
    c_message = @store.report(Logger::WARN, "test", "C", timestamp: Time.now + (24 * 60 * 60), env: env)
    @store.protect c_message.key
    d_message = @store.report(Logger::WARN, "test", "D", env: env)
    10.times do
      @store.report(Logger::WARN, "test", "E", env: env)
    end

    latest = @store.latest
    assert_equal(25, latest.length)

    @store.clear

    # Protected messages are still accessible by their key
    assert_equal("C", @store.get(c_message.key).message)
    assert(env <= @store.get_env(c_message.key))
    # Unprotected messages are gone
    assert_nil(@store.get(d_message.key))
    assert_nil(@store.get_env(d_message.key))

    # The latest list is rebuilt with protected messages, earliest first
    # Including messages that previously fell off (A)
    latest = @store.latest
    assert_equal(2, latest.length)
    assert_equal("A", latest[0].message)
    assert_equal("C", latest[1].message)
    assert(env <= latest[0].env)
    assert(env <= latest[1].env)
  end

  def test_clear_deletes_pattern_groups_if_not_protected
    Logster.config.enable_custom_patterns_via_ui = true
    Logster.config.allow_grouping = true
    Logster::GroupingPattern.new(/discourse/, store: @store).save
    Logster::GroupingPattern.new(/logster/, store: @store).save
    msg = @store.report(Logger::WARN, '', 'discourse')
    @store.protect(msg.key)
    @store.report(Logger::WARN, '', 'logster')
    groups = @store.find_pattern_groups
    assert_equal 2, groups.size

    @store.clear
    groups = @store.find_pattern_groups
    assert_equal 1, groups.size
    assert_equal msg.key, groups[0].messages_keys[0]
    assert_equal '/discourse/', groups[0].key

    @store.unprotect(msg.key)
    @store.clear
    groups = @store.find_pattern_groups
    assert_equal 0, groups.size
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
    Logster.config.allow_grouping = false
  end

  def test_hash_cleanup
    @store.max_backlog = 2
    a_message = @store.report(Logger::WARN, "test", "A")
    @store.report(Logger::WARN, "test", "B")
    @store.report(Logger::WARN, "test", "C")

    assert_nil(@store.get(a_message.key))
  end

  def test_filter_latest
    @store.report(Logger::INFO, "test", "A")
    @store.report(Logger::WARN, "test", "B")

    messages = @store.latest
    assert_equal(2, messages.length)

    messages = @store.latest(after: messages.last.key)
    assert_equal(0, messages.length)

    10.times do
      @store.report(Logger::INFO, "test", "A")
    end
    @store.report(Logger::ERROR, "test", "C")
    10.times do
      @store.report(Logger::INFO, "test", "A")
    end

    latest = @store.latest(severity: [Logger::ERROR, Logger::WARN], limit: 2)

    assert_equal(2, latest.length)
    assert_equal("B", latest[0].message)
    assert_equal("C", latest[1].message)

    @store.report(Logger::ERROR, "test", "E")
    # respects after
    latest = @store.latest(severity: [Logger::ERROR, Logger::WARN], limit: 2, after: latest[1].key)
    assert_equal(1, latest.length)
  end

  def test_search
    @store.report(Logger::INFO, "test", "ABCDEFG")
    @store.report(Logger::INFO, "test", "TUVWXYZ")

    messages = @store.latest
    assert_equal(2, messages.length)

    latest = @store.latest(search: "TUVWXYZ")

    assert_equal(1, latest.length)
    assert_equal("TUVWXYZ", latest[0].message)
  end

  def test_search_exclude_results
    @store.report(Logger::INFO, "test", "ABCDEFG")
    @store.report(Logger::INFO, "test", "TUVWXYZ")

    messages = @store.latest
    assert_equal(2, messages.length)

    latest = @store.latest(search: "-ABCD")

    assert_equal(1, latest.length)
    assert_equal("TUVWXYZ", latest[0].message)
  end

  def test_regex_search
    @store.report(Logger::INFO, "test", "pattern_1")
    @store.report(Logger::INFO, "test", "pattern_2")

    messages = @store.latest
    assert_equal(2, messages.length)

    latest = @store.latest(search: /^pattern_[1]$/)

    assert_equal(1, latest.length)
  end

  def test_env_search
    @store.report(Logger::INFO, "test", "message ABCD", env: { cluster: "business5" })
    @store.report(Logger::INFO, "test", "message WXYZ", env: { cluster: "business7" })

    messages = @store.latest
    assert_equal(2, messages.length)

    latest = @store.latest(search: "business5")

    assert_equal(1, latest.length)
    assert_equal("message ABCD", latest[0].message)

    latest = @store.latest(search: "-business5")

    assert_equal(1, latest.length)
    assert_equal("message WXYZ", latest[0].message)

    latest = @store.latest(search: /business/)

    assert_equal(2, latest.length)
    assert_equal(["message ABCD", "message WXYZ"], latest.map(&:message).sort)
  end

  def test_array_env_search_preserve_env
    m1_original_env = [{ cluster: "business5" }, { cluster: "standard3" }]
    m2_original_env = [{ cluster: "business2" }, { cluster: "standard7" }]

    @store.report(Logger::INFO, "test", "message ABCD", env: m1_original_env, count: 2)
    @store.report(Logger::INFO, "test", "message WXYZ", env: m2_original_env, count: 2)

    messages = @store.latest
    assert_equal(2, messages.length)

    m1_key = messages[0].key
    m2_key = messages[1].key

    messages = @store.latest(search: "business")
    assert_equal(2, messages.size)

    # any hashes that don't match should be stripped from the env
    # array but only temporarily until it's sent to the client
    # env array should remain untouched in redis memory
    assert_equal(["business5"], messages[0].env.map { |env| env["cluster"] })
    assert_equal(1, messages[0].count)
    assert_equal(["business2"], messages[1].env.map { |env| env["cluster"] })
    assert_equal(1, messages[1].count)

    m1 = @store.get(m1_key)
    m2 = @store.get(m2_key)
    # original env should preserved in redis memory
    assert_equal(["business5", "standard3"], m1.env.map { |env| env["cluster"] })
    assert_equal(["business2", "standard7"], m2.env.map { |env| env["cluster"] })
  end

  def test_both_env_and_title_match_search
    @store.report(Logger::INFO, "test", "message", env: [{ cluster: "business15" }])
    @store.report(Logger::INFO, "test", "message2", env: { cluster: "business15" })

    messages = @store.latest
    assert_equal(2, messages.size)

    messages = @store.latest(search: "-business15")
    assert_equal(0, messages.size)
  end

  def test_data_kept_intact_on_report_when_env_matches_an_ignore_pattern
    begin
      Logster.config.allow_grouping = true
      backtrace = caller
      message = @store.report(Logger::WARN, "", "my error", env: { whatever: "something", backtrace: backtrace })

      @store.ignore = [
          Logster::IgnorePattern.new("business")
      ]
      @store.report(Logger::WARN, "", "my error", env: { cluster: "business17", backtrace: backtrace })

      message = @store.get(message.key)
      assert(Array === message.env)
      assert_equal(2, message.env.size)
      # message2 shouldn't vanish even if
      # its env matches an ignore pattern
      # however it should be merged with message1
      assert_equal("business17", message.env[0]["cluster"])
    ensure
      # reset so it doesn't affect other tests
      @store.ignore = nil
      Logster.config.allow_grouping = false
    end
  end

  def test_array_env_negative_search
    @store.report(Logger::INFO, "test", "message ABCD", env: [{ cluster: "business5" }, { cluster: "standard3" }], count: 2)
    @store.report(Logger::INFO, "test", "message WXYZ", env: [{ cluster: "business2" }, { cluster: "standard7" }], count: 2)

    messages = @store.latest
    assert_equal(2, messages.length)

    messages = @store.latest(search: "-business")
    assert_equal(2, messages.size)

    assert_equal(["standard3"], messages[0].env.map { |env| env["cluster"] })
    assert_equal(1, messages[0].count)
    assert_equal(["standard7"], messages[1].env.map { |env| env["cluster"] })
    assert_equal(1, messages[1].count)
  end

  def test_negative_search_MUST_not_match_title_in_order_to_include_message
    @store.report(Logger::INFO, "test", "message ABCD", env: [{ cluster: "business5" }, { cluster: "standard3" }], count: 2)

    messages = @store.latest(search: "-ABCD")
    assert_equal(0, messages.size) # cause title has ABCD
  end

  def test_positive_search_looks_at_title_OR_env
    @store.report(Logger::INFO, "test", "message", env: [{ cluster: "business5 ABCDEFG" }, { cluster: "standard3" }], count: 2)

    messages = @store.latest(search: "ABCDEFG")
    assert_equal(1, messages.size)
    assert_equal(1, messages[0].env.size)
    assert_equal("business5 ABCDEFG", messages[0].env[0]["cluster"])
  end

  def test_backtrace
    @store.report(Logger::INFO, "test", "pattern_1")
    message = @store.latest(limit: 1).first
    assert_match("test_backtrace", message.backtrace)
  end

  def test_ignore
    @store.ignore = [/^test/]
    @store.report(Logger::INFO, "test", "test it")
    @store.report(Logger::INFO, "test", " test it")

    assert_equal(1, @store.latest.count)
  end

  def test_solve
    Logster.config.application_version = "abc"

    @store.report(Logger::WARN, "application", "test error1", backtrace: "backtrace1")
    m = @store.report(Logger::WARN, "application", "test error2", backtrace: "backtrace1")
    @store.report(Logger::WARN, "application", "test error1", backtrace: "backtrace2")

    assert_equal(3, @store.latest.count)

    @store.solve(m.key)

    assert_equal(1, @store.latest.count)

    @store.report(Logger::WARN, "application", "test error1", backtrace: "backtrace1")
    @store.report(Logger::WARN, "application", "test error1", backtrace: "backtrace1", env: { "application_version" => "xyz" })

    assert_equal(2, @store.latest.count)

  ensure
    Logster.config.application_version = nil
  end

  def test_solve_grouped
    Logster.config.allow_grouping = true
    @store.report(Logger::WARN, "application", "test error1", backtrace: "backtrace1", env: { "application_version" => "xyz" })
    m = @store.report(Logger::WARN, "application", "test error1", backtrace: "backtrace1", env: { "application_version" => "efg" })

    assert_equal(1, @store.latest.count)

    @store.solve(m.key)

    @store.report(Logger::WARN, "application", "test error1", backtrace: "backtrace1", env: { "application_version" => "xyz" })
    @store.report(Logger::WARN, "application", "test error1", backtrace: "backtrace1", env: { "application_version" => "efg" })

    assert_equal(0, @store.latest.count)

  ensure
    Logster.config.allow_grouping = false
  end

  def test_clears_solved
    m = @store.report(Logger::WARN, "application", "test error2", backtrace: "backtrace1", env: { "application_version" => "abc" })
    @store.solve(m.key)

    assert_equal(1, @store.solved.length)

    @store.clear
    assert_equal(0, @store.solved.length)
  end

  def test_solving_with_some_missing_version

    m = @store.report(Logger::WARN, "application", "test error1", backtrace: "backtrace1", env: { "application_version" => "xyz" })
    @store.report(Logger::WARN, "application", "test error1", backtrace: "backtrace1")

    @store.solve(m.key)

    assert_equal(1, @store.latest.count)
  end

  def test_env
    env = Rack::MockRequest.env_for("/test").merge(
      "HTTP_HOST" => "www.site.com",
      "HTTP_USER_AGENT" => "SOME WHERE"
    )
    orig = env.dup
    orig["test"] = "tests"
    orig["test1"] = "tests1"
    Logster.add_to_env(env, "test", "tests")
    Logster.add_to_env(env, "test1", "tests1")

    orig.delete_if do |k, v|
      !%w{
        HTTP_HOST
        REQUEST_METHOD
        HTTP_USER_AGENT
        test
        test1
      }.include? k
    end

    @store.report(Logger::INFO, "test", "test",  env: env)

    env = @store.latest.last.env

    env.delete "hostname"
    env.delete "process_id"

    assert_equal(orig, env)
  end

  def test_custom_ignore_patterns_work_with_per_store_config
    Logster.config.enable_custom_patterns_via_ui = false
    @store.allow_custom_patterns = true
    Logster::SuppressionPattern.new("/testtesttest/", store: @store).save
    @store.report(Logger::INFO, "test", "testtesttesttest")
    latest = @store.latest
    assert_equal(0, latest.size)

    @store.allow_custom_patterns = false
    @store.report(Logger::INFO, "test", "testtesttesttest")
    latest = @store.latest
    assert_equal(1, latest.size)
    assert_equal("testtesttesttest", latest.first.message)
  end

  def test_suppressed_logs_are_counted
    @store.ignore = [/store ignore/, Logster::IgnorePattern.new(/ignore pattern/), "an ignore string"]
    @store.allow_custom_patterns = true
    Logster::SuppressionPattern.new(/sup pattern/, store: @store).save

    2.times do
      @store.report(Logger::INFO, "test", "this is store ignore")
      @store.report(Logger::INFO, "test", "this is ignore pattern")
      @store.report(Logger::INFO, "test", "this is sup pattern")
      @store.report(Logger::INFO, "test", "this is an ignore string")
    end

    ignore_pattern = Logster::IgnorePattern.new(/ignore pattern/)
    hash = @store.get_all_ignore_count
    assert_equal("2", hash[ignore_pattern.to_s])
    assert_equal("2", hash[/sup pattern/.inspect])
    assert_equal("2", hash[/store ignore/.inspect])
    assert_equal("2", hash["an ignore string"])

    @store.remove_ignore_count(ignore_pattern.to_s)
    hash = @store.get_all_ignore_count
    assert_nil(hash[ignore_pattern.to_s])
  end

  def test_rate_limits
    %w{minute hour}.each do |duration|
      begin
        called = false

        assert_instance_of(
          Logster::RedisRateLimiter,
          @store.public_send("register_rate_limit_per_#{duration}", Logger::WARN, 0) do
            called = true
          end
        )

        @store.report(Logger::WARN, "test", "test")
        assert called
      ensure
        reset_redis
      end
    end
  end

  def test_rate_limits_only_checks_when_message_is_bumped_or_saved
    Logster.config.allow_grouping = true
    Logster.config.application_version = 'abc'

    @store.ignore = [/^ActiveRecord::RecordNotFound/]
    rate_limit = @store.register_rate_limit_per_minute(Logger::WARN, 0)

    message = @store.report(Logger::WARN, 'message 1', "Error!", backtrace: 'here')
    assert_equal(1, rate_limit.retrieve_rate)

    @store.report(Logger::WARN, 'message 1', "Error!", backtrace: 'here')
    assert_equal(2, rate_limit.retrieve_rate)

    @store.solve(message.key)
    @store.report(Logger::WARN, 'message 1', "Error!", backtrace: 'here')
    assert_equal(2, rate_limit.retrieve_rate)

    @store.report(Logger::WARN, 'message 2', "Error!")
    assert_equal(3, rate_limit.retrieve_rate)

    @store.report(Logger::WARN, 'message 3', "ActiveRecord::RecordNotFound")
    assert_equal(3, rate_limit.retrieve_rate)
  ensure
    Logster.config.allow_grouping = false
    Logster.config.application_version = nil
    reset_redis
  end

  def test_rate_limits_with_prefix
    begin
      time = Time.now
      Timecop.freeze(time)
      current_namespace = 'first'
      @store.redis_prefix = Proc.new { current_namespace }

      called_first = 0
      called_second = 0

      @store.register_rate_limit_per_minute(Logger::WARN, 0) { called_first += 1 }
      @store.report(Logger::WARN, "test", "test")
      assert_equal(1, called_first)

      current_namespace = 'second'
      @store.register_rate_limit_per_minute(Logger::WARN, 0) { called_second += 1 }
      @store.report(Logger::WARN, "test", "test")
      assert_equal(1, called_first)
      assert_equal(1, called_second)

      Timecop.freeze(time + 10) do
        current_namespace = 'first'
        @store.report(Logger::WARN, "test", "test")

        assert_equal(2, called_first)
        assert_equal(1, called_second)
      end
    ensure
      reset_redis
    end
  end

  def test_suppression_patterns_are_cached
    @store.allow_custom_patterns = true
    rec = Logster::SuppressionPattern.new(/forest/, store: @store)
    rec.save

    @store.report(Logger::INFO, "test", "littleforest")
    latest = @store.latest
    assert_equal(0, latest.size)

    rec.destroy(clear_cache: false)
    @store.report(Logger::INFO, "test", "anotherforest")
    assert_equal(0, @store.latest.size)

    Process.stub :clock_gettime, Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3 do
      @store.report(Logger::INFO, "test", "myforest")
      latest = @store.latest
      assert_equal(1, latest.size)
      assert_equal("myforest", latest.first.message)
    end
  end

  def test_ensure_messages_meet_config_size_limits_when_messages_are_saved
    config_reset(
      maximum_message_size_bytes: 300,
      max_env_bytes: 30,
      max_env_count_per_message: 5
    ) do
      env = [{ aaa: 111, bbb: 222, ccc: 333, ddd: 444 }] * 7
      message = @store.report(Logger::WARN, '', 'test', backtrace: "aa\n" * 100, env: env.dup, timestamp: 777)
      message = @store.get(message.key)
      assert_operator(message.to_json(exclude_env: true).bytesize, :<, 300)
      assert_equal(5, message.env.size)
      message.env.each do |e|
        assert_operator(e.to_json.bytesize, :<=, 30)
        assert_equal({ "aaa" => 111, "time" => 777 }, e)
      end
    end
  end

  def test_ensure_messages_meet_config_size_limits_when_merged_together

    config_reset(
      max_env_bytes: 30,
      max_env_count_per_message: 5,
      allow_grouping: true
    ) do
      env = [{ a: 1, aa: 22, aaa: 333, aaaa: 4444 }] * 3
      env_2 = [{ b: 1, bb: 22, bbb: 333, bbbb: 4444 }] * 3
      @store.report(Logger::WARN, '', 'test', backtrace: "aa\n" * 100, env: env.dup, timestamp: 777)
      message = @store.report(Logger::WARN, '', 'test', backtrace: "aa\n" * 100, env: env_2.dup, timestamp: 777)
      message = @store.get(message.key)
      assert_equal(5, message.env.size)
      message.env.first(3).each do |e|
        assert_operator(e.to_json.bytesize, :<=, 30)
        assert_equal({ "b" => 1, "bb" => 22, "time" => 777 }, e)
      end
      message.env.last(2).each do |e|
        assert_operator(e.to_json.bytesize, :<=, 30)
        assert_equal({ "a" => 1, "aa" => 22, "time" => 777 }, e)
      end
    end
  end

  def test_custom_grouping_patterns
    Logster.config.enable_custom_patterns_via_ui = true
    Logster::GroupingPattern.new(/delete/, store: @store).save
    msg1 = @store.report(Logger::WARN, '', 'delete this plz', timestamp: 1)
    msg2 = @store.report(Logger::WARN, '', 'delete that plz', timestamp: 2)
    group = @store.find_pattern_groups(load_messages: true)[0]
    assert_equal 2, group.count
    assert_equal "/delete/", group.key
    assert_equal [msg2.key, msg1.key], group.messages_keys
    assert_equal msg2.timestamp, group.timestamp
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_custom_grouping_patterns_with_similar_messages_grouping
    Logster.config.enable_custom_patterns_via_ui = true
    Logster.config.allow_grouping = true
    Logster::GroupingPattern.new(/delete/, store: @store).save
    backtrace = caller
    @store.report(Logger::WARN, '', 'delete this plz', backtrace: backtrace, timestamp: 1)
    msg2 = @store.report(Logger::WARN, '', 'delete that plz', backtrace: backtrace, timestamp: 2)
    msg3 = @store.report(Logger::WARN, '', 'delete this plz', backtrace: backtrace, timestamp: 3)
    group = @store.find_pattern_groups(load_messages: false)[0]
    assert_equal 2, group.count
    assert_equal [msg3.key, msg2.key], group.messages_keys
    assert_equal msg3.timestamp, group.timestamp
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
    Logster.config.allow_grouping = false
  end

  def test_a_single_message_can_be_in_one_grouping_pattern
    Logster.config.enable_custom_patterns_via_ui = true
    Logster::GroupingPattern.new(/delete/, store: @store).save
    Logster::GroupingPattern.new(/env/, store: @store).save
    @store.report(Logger::WARN, '', 'delete and env')
    groups = @store.find_pattern_groups
    assert_equal 1, groups.size
    assert_includes ["/delete/", "/env/"], groups[0].key
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_find_pattern_groups_works_correctly
    Logster.config.enable_custom_patterns_via_ui = true
    with_search = Logster::GroupingPattern.new(/with search/, store: @store)
    with_search.save
    Logster::GroupingPattern.new(/pattern group/, store: @store).save

    groups = @store.find_pattern_groups
    assert_equal 0, groups.size # because there are no messages yet

    2.times do |n|
      @store.report(Logger::WARN, '', "with search #{n}")
      @store.report(Logger::WARN, '', "pattern group #{n}")
    end
    groups = @store.find_pattern_groups
    assert_equal 2, groups.size
    groups.each do |g|
      assert_equal 2, g.count
      assert_nil g.messages
    end

    groups = @store.find_pattern_groups(load_messages: true)
    assert_equal 2, groups.size
    groups.each do |g|
      assert_equal 2, g.count
      assert_equal 2, g.messages.size
      g.messages.each { |m| assert Logster::Message === m }
    end

    groups = @store.find_pattern_groups(load_messages: true) { |pat| pat == with_search.pattern }
    assert_equal 1, groups.size
    assert_equal 2, groups[0].count
    assert groups[0].messages.all? { |m| m.message =~ /with search/ }
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_trimming_backlog_removes_messages_from_custom_grouping
    prev_max_backlog = @store.max_backlog
    @store.max_backlog = 4
    Logster.config.enable_custom_patterns_via_ui = true
    Logster::GroupingPattern.new(/trim/, store: @store).save
    keys = []
    5.times do |n|
      keys << @store.report(Logger::WARN, '', "trim backlog #{n}").key
    end
    groups = @store.find_pattern_groups
    assert_equal 1, groups.size
    assert_equal 4, groups[0].messages_keys.size
    assert_equal 5, groups[0].count
    assert_equal keys[1..-1].reverse, groups[0].messages_keys
  ensure
    @store.max_backlog = prev_max_backlog
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_adding_grouping_pattern_works_retroactively
    Logster.config.enable_custom_patterns_via_ui = true
    @store.report(Logger::WARN, '', 'trim this plz')
    @store.report(Logger::WARN, '', 'trim that plz')
    Logster::GroupingPattern.new(/trim/, store: @store).save
    results = @store.latest
    assert_equal 1, results.size
    assert_equal 2, results[0].messages.size

    @store.report(Logger::WARN, '', 'trim this more plz')
    results = @store.latest
    assert_equal 1, results.size
    assert_equal 3, results[0].messages.size
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_adding_grouping_pattern_doesnt_add_a_message_to_more_than_one_group
    Logster.config.enable_custom_patterns_via_ui = true
    @store.report(Logger::WARN, '', 'trim this plz')
    @store.report(Logger::WARN, '', 'trim this plz 2')
    Logster::GroupingPattern.new(/trim/, store: @store).save
    Logster::GroupingPattern.new(/this/, store: @store).save
    groups = @store.find_pattern_groups
    assert_equal 1, groups.size
    assert_equal 2, groups[0].count
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
  end

  def test_latest_doesnt_include_rows_that_are_removed_from_grouping_patterns_due_to_max_size
    Logster.config.enable_custom_patterns_via_ui = true
    Logster::Group.instance_variable_set(:@max_size, 5)
    msg1 = @store.report(Logger::WARN, '', 'first message')
    msg2 = @store.report(Logger::WARN, '', 'second message')
    Logster::GroupingPattern.new(/noisy/, store: @store).save

    grouped = []
    7.times do |n|
      grouped << @store.report(Logger::WARN, '', "noisy message #{n}", timestamp: n).key
    end
    msg3 = @store.report(Logger::WARN, '', 'third message')
    results = @store.latest

    assert_equal [msg1.key, msg2.key, '/noisy/', msg3.key], results.map(&:key)
    assert_equal grouped.reverse.first(5), results[2].messages.map(&:key)
  ensure
    Logster.config.enable_custom_patterns_via_ui = false
    Logster::Group.remove_instance_variable(:@max_size)
  end

  def test_truncated_messages_when_they_are_similar_can_still_be_merged
    config_reset(allow_grouping: true) do
      backtrace = "a" * Logster.config.maximum_message_size_bytes
      title = "sasasas"
      msg = @store.report(Logger::WARN, '', title, backtrace: backtrace.dup)
      msg2 = @store.report(Logger::WARN, '', title, backtrace: backtrace.dup)
      assert_equal(msg.key, msg2.key)
      assert_operator(msg.to_json(exclude_env: true).bytesize, :<=, Logster.config.maximum_message_size_bytes)
      assert_operator(msg.backtrace.size, :<, backtrace.size)
    end
  end

  def test_messages_that_differ_only_by_numbers_or_hashes_are_merged
    config_reset(allow_grouping: true) do
      first_message = <<~TEXT
        DistributedMutex("download_20450e291e8f1e5ba03ca7f20fb7d9da570c94a6"):
        held for too long, expected max: 60 secs, took an extra 73 secs
      TEXT
      msg = @store.report(Logger::WARN, '', first_message, backtrace: caller)

      second_message = <<~TEXT
        DistributedMutex("download_e09ae082c60a351dedec67ed869652862b232a0b"):
        held for too long, expected max: 60 secs, took an extra 287 secs
      TEXT
      msg2 = @store.report(Logger::WARN, '', second_message, backtrace: caller)

      assert_equal(msg.key, msg2.key)
    end
  end

  private

  def config_reset(configs)
    defaults = {}
    configs.each do |k, v|
      defaults[k] = Logster.config.public_send(k)
      Logster.config.public_send("#{k}=", v)
    end
    yield
  ensure
    defaults.each do |k, v|
      Logster.config.public_send("#{k}=", v)
    end
  end

  def reset_redis
    @store.clear_all
  end
end

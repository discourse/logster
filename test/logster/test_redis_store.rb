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
        assert_equal(Logster::Message.default_env, msg.env)
      else
        assert({ "test_#{n}" => "envsss" } <= msg.env)
      end
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

    unsaved_env = { "unsaved_env" => "lost value" }
    message.env = unsaved_env

    @store.replace_and_bump(message, save_env: false)

    message = @store.get(message.key)
    assert(old_env <= message.env)
    refute(unsaved_env <= message.env)

    saved_env = { "saved_env" => "saved value!" }
    message.env = saved_env

    @store.replace_and_bump(message)

    message = @store.get(message.key)
    assert(saved_env == message.env)
  end

  def test_backward_compatibility_no_loss_of_data
    # previously we were storing env samples as a part of the main message json
    # now we've switched to storing samples separately from the main message
    # we need to make we don't lose env data of messages stored the old way
    # when we migrate to the new system

    # it probably makes sense to remove this test after a while (say 6-12 months)

    Logster.config.allow_grouping = true
    backtrace = "fake backtrace"
    env = { "some_env" => "some env" }
    message = Logster::Message.new(Logger::WARN, "", "title", count: 60)
    message.env = env
    message.backtrace = backtrace

    @store.save(message)

    # hack to force env to be stored with the main message json
    @store.redis.hset(@store.send("hash_key"), message.key, message.to_json(exclude_env: false))

    another_env = { "another_env" => "more env" }
    message = @store.report(Logger::WARN, "", "title", backtrace: backtrace, env: another_env)
    message = @store.get(message.key)

    assert(env <= message.env)
    assert_equal(61, message.count)
    # another_env is not merged cause count is 60, only the count is updated

    # make sure we are now storing env samples separately
    message = @store.get(message.key, load_env: false)
    assert_nil(message.env)
  ensure
    Logster.config.allow_grouping = false
  end

  def test_backward_compatibility_no_loss_of_data_2
    # same story as the test above, just a bit different

    Logster.config.allow_grouping = true
    backtrace = "fake backtrace"
    env = { "some_env" => "some env" }
    message = Logster::Message.new(Logger::WARN, "", "title")
    message.env = env
    message.backtrace = backtrace

    @store.save(message)

    # hack to force env to be stored with the main message json
    @store.redis.hset(@store.send("hash_key"), message.key, message.to_json(exclude_env: false))

    another_env = { "another_env" => "more env" }
    message = @store.report(Logger::WARN, "", "title", backtrace: backtrace, env: another_env)
    message = @store.get(message.key)

    assert_instance_of(Array, message.env)
    assert(env <= message.env[0])
    assert(another_env <= message.env[1])
    assert_equal(2, message.env.size)
    assert_equal(2, message.count)

    # make sure we are now storing env samples separately
    message = @store.get(message.key, load_env: false)
    assert_nil(message.env)
  ensure
    Logster.config.allow_grouping = false
  end

  def test_merging_performance
    Logster.config.allow_grouping = true
    backtrace = "fake backtrace"
    env = { "some_env" => "some env" }
    another_env = { "another_env" => "more env" }
    yet_another_env = { "moaar_env" => "more env" }

    @store.report(Logger::WARN, "", "title", backtrace: backtrace, env: env, count: 49)

    message = @store.report(Logger::WARN, "", "title", backtrace: backtrace, env: another_env)
    assert_instance_of(Array, message.env)
    assert_equal(2, message.env.size)
    assert(env <= message.env[0])
    assert(another_env <= message.env[1])

    message = @store.report(Logger::WARN, "", "title", backtrace: backtrace, env: yet_another_env)
    # we don't need to load env from redis cause we don't
    # need to merge new env samples if count is 50 or more
    assert_nil(message.env)
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
      assert_equal("business17", message.env[1]["cluster"])
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
    @store.allow_custom_ignore = true
    Logster::SuppressionPattern.new("/testtesttest/", store: @store).save
    @store.report(Logger::INFO, "test", "testtesttesttest")
    latest = @store.latest
    assert_equal(0, latest.size)

    @store.allow_custom_ignore = false
    @store.report(Logger::INFO, "test", "testtesttesttest")
    latest = @store.latest
    assert_equal(1, latest.size)
    assert_equal("testtesttesttest", latest.first.message)
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

  private

  def reset_redis
    @store.redis.flushall
  end
end

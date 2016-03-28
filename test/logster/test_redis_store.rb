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
    msg = @store.report(Logger::WARN, "test", "testing")
    @store.delete(msg)
    latest = @store.latest

    assert_equal(0,latest.length)
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
    a_message = @store.report(Logger::WARN, "test", "A")
    b_message = @store.report(Logger::WARN, "test", "B")
    @store.report(Logger::WARN, "test", "C")

    assert_equal("A", @store.get(a_message.key).message)
    assert_equal("B", @store.get(b_message.key).message)
  end

  def test_backlog
    @store.max_backlog = 1
    @store.report(Logger::WARN, "test", "A")
    @store.report(Logger::WARN, "test", "A")
    @store.report(Logger::WARN, "test", "A")
    @store.report(Logger::WARN, "test", "B")

    latest = @store.latest

    assert_equal(1, latest.length)
    assert_equal("B", latest[0].message)
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
    @store.max_backlog = 25
    a_message = @store.report(Logger::WARN, "test", "A", timestamp: Time.now - (24*60*60))
    @store.protect a_message.key
    20.times do
      @store.report(Logger::WARN, "test", "B")
    end
    c_message = @store.report(Logger::WARN, "test", "C", timestamp: Time.now + (24*60*60))
    @store.protect c_message.key
    d_message = @store.report(Logger::WARN, "test", "D")
    10.times do
      @store.report(Logger::WARN, "test", "E")
    end

    latest = @store.latest
    assert_equal(25, latest.length)

    @store.clear

    # Protected messages are still accessible by their key
    assert_equal("C", @store.get(c_message.key).message)
    # Unprotected messages are gone
    assert_nil(@store.get(d_message.key))

    # The latest list is rebuilt with protected messages, earliest first
    # Including messages that previously fell off (A)
    latest = @store.latest
    assert_equal(2, latest.length)
    assert_equal("A", latest[0].message)
    assert_equal("C", latest[1].message)
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
    assert_equal(1, latest.length);
  end

  def test_search
    @store.report(Logger::INFO, "test", "A")
    @store.report(Logger::INFO, "test", "B")

    messages = @store.latest
    assert_equal(2, messages.length)

    latest = @store.latest(search: "B")

    assert_equal(1, latest.length)
  end

  def test_regex_search
    @store.report(Logger::INFO, "test", "pattern_1")
    @store.report(Logger::INFO, "test", "pattern_2")

    messages = @store.latest
    assert_equal(2, messages.length)

    latest = @store.latest(search: /^pattern_[1]$/)

    assert_equal(1, latest.length)
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
    @store.report(Logger::WARN, "application", "test error1", backtrace: "backtrace1", env: { "application_version" => "xyz"})

    assert_equal(2, @store.latest.count)

  ensure
    Logster.config.application_version = nil
  end

  def test_solve_grouped
    Logster.config.allow_grouping = true
    @store.report(Logger::WARN, "application", "test error1", backtrace: "backtrace1", env: { "application_version" => "xyz"})
    m = @store.report(Logger::WARN, "application", "test error1", backtrace: "backtrace1", env: { "application_version" => "efg"})

    assert_equal(1, @store.latest.count)

    @store.solve(m.key)

    @store.report(Logger::WARN, "application", "test error1", backtrace: "backtrace1", env: { "application_version" => "xyz"})
    @store.report(Logger::WARN, "application", "test error1", backtrace: "backtrace1", env: { "application_version" => "efg"})

    assert_equal(0, @store.latest.count)

  ensure
    Logster.config.allow_grouping = false
  end

  def test_clears_solved
    m = @store.report(Logger::WARN, "application", "test error2", backtrace: "backtrace1", env: {"application_version" => "abc"})
    @store.solve(m.key)

    assert_equal(1, @store.solved.length)

    @store.clear
    assert_equal(0, @store.solved.length)
  end

  def test_solving_with_some_missing_version

    m=@store.report(Logger::WARN, "application", "test error1", backtrace: "backtrace1", env: { "application_version" => "xyz"})
    @store.report(Logger::WARN, "application", "test error1", backtrace: "backtrace1")

    @store.solve(m.key)

    assert_equal(1, @store.latest.count)
  end

  def test_env
    env = Rack::MockRequest.env_for("/test").merge({
      "HTTP_HOST" => "www.site.com",
      "HTTP_USER_AGENT" => "SOME WHERE"
    })
    orig = env.dup
    orig["test"] = "tests"
    orig["test1"] = "tests1"
    Logster.add_to_env(env,"test","tests")
    Logster.add_to_env(env,"test1","tests1")

    orig.delete_if do |k,v|
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

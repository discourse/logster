require_relative '../test_helper'
require 'logster/redis_store'
require 'rack'

class TestRedisStore < Minitest::Test

  def setup
    @store = Logster::RedisStore.new(Redis.new)
    @store.clear
  end

  def teardown
    @store.clear
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
    10.times do |i|
      @store.report(Logger::WARN, "test", "A#{i}")
    end
    10.times do |i|
      @store.report(Logger::WARN, "test", "B#{i}")
    end
    10.times do |i|
      @store.report(Logger::WARN, "test", "C#{i}")
    end

    messages = @store.latest(limit: 10)
    assert_equal("C0", messages[0].message)
    assert_equal(10, messages.length)

    messages = @store.latest(limit: 10, before: messages[0].key)
    assert_equal("B0", messages[0].message)
    assert_equal(10, messages.length)

    messages = @store.latest(limit: 10, before: messages[0].key)
    assert_equal("A0", messages[0].message)
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
    @store.report(Logger::WARN, "test", "C")
    @store.report(Logger::WARN, "test", "A")
    @store.report(Logger::WARN, "test", "B")

    latest = @store.latest

    assert_equal(1, latest.length)
    assert_equal("B", latest[0].message)
  end

  def test_save_unsave
    @store.max_backlog = 2
    @store.report(Logger::WARN, "test", "A")
    b_message = @store.report(Logger::WARN, "test", "B")
    @store.protect b_message.key
    c_message = @store.report(Logger::WARN, "test", "C")
    @store.protect c_message.key
    @store.report(Logger::WARN, "test", "D")

    latest = @store.latest

    assert_equal(2, latest.length)
    assert_equal("C", latest[0].message)
    assert_equal("D", latest[1].message)

    # Saved messages still accessible by key
    assert_equal("B", @store.get(b_message.key).message)
    assert_equal(true, @store.get(b_message.key).protected)

    # Unsave does not delete message if still recent
    @store.unprotect c_message.key
    assert_equal("C", @store.get(c_message.key).message)
    assert_equal(false, @store.get(c_message.key).protected)

    # Unsave *does* delete message if not recent
    @store.unprotect b_message.key
    assert_nil(@store.get(b_message.key))
  end

  def test_clear
    10.times do |i|
      @store.report(Logger::WARN, "test", "A#{i}")
    end
    # Protected messages are not deleted
    b_message = @store.report(Logger::WARN, "test", "B")
    @store.protect b_message.key
    c_message = @store.report(Logger::WARN, "test", "C")
    10.times do |i|
      @store.report(Logger::WARN, "test", "D#{i}")
    end

    latest = @store.latest
    assert_equal(22, latest.length)

    @store.clear

    latest = @store.latest
    assert_equal(0, latest.length)
    assert_equal("B", @store.get(b_message.key).message)
    assert_nil(@store.get(c_message.key))
  end

  def test_hash_cleanup
    @store.max_backlog = 2
    a_message = @store.report(Logger::WARN, "test", "A")
    @store.report(Logger::WARN, "test", "B")
    @store.report(Logger::WARN, "test", "C")

    assert_nil(@store.get(a_message.key))
  end

  def test_grouping
    @store.report(Logger::INFO, "test", "Q")
    10.times do
      @store.report(Logger::WARN, "test", "Q")
    end
    @store.report(Logger::WARN, "test", "Blah")
    @store.report(Logger::WARN, "Different", "Q")

    latest = @store.latest
    assert_equal(4, latest.length)
    assert_equal(10, latest[1].count)
  end

  def test_filter_latest
    @store.report(Logger::INFO, "test", "A")
    @store.report(Logger::WARN, "test", "B")

    messages = @store.latest
    assert_equal(2, messages.length)

    messages = @store.latest(after: messages.last.key)
    assert_equal(0, messages.length)

    10.times do |i|
      @store.report(Logger::INFO, "test", "A#{i}")
    end
    @store.report(Logger::ERROR, "test", "C")
    10.times do |i|
      @store.report(Logger::INFO, "test", "A#{i}")
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
    assert_equal(orig, @store.latest.last.env)
  end

end

# frozen_string_literal: true

require_relative "../test_helper"
require "logster/base_store"
require "logster/ignore_pattern"

class TestBaseStore < Minitest::Test
  def setup
    @store = Logster::TestStore.new
    @store.clear_all
  end

  def teardown
    @store.clear_all
  end

  def test_report_skip_empty
    @store.skip_empty = true
    @store.report(Logger::WARN, "test", nil)
    @store.report(Logger::WARN, "test", "")
    @store.report(Logger::WARN, "test", "foo") #
    @store.skip_empty = false
    @store.report(Logger::WARN, "test", nil) #

    assert_equal(2, @store.count)
  end

  def test_report_skip_level
    @store.level = nil
    @store.report(Logger::DEBUG, "test", "A") #
    @store.level = Logger::WARN
    @store.report(Logger::DEBUG, "test", "A")
    @store.report(Logger::INFO, "test", "B")
    @store.report(Logger::WARN, "test", "C") #
    @store.report(Logger::ERROR, "test", "D") #
    assert_equal(3, @store.count)
  end

  def test_report_skip_ignore
    @store.report(Logger::WARN, "test", "Can't verify CSRF token authenticity")
    @store.report(
      Logger::FATAL,
      "test",
      "ActiveRecord::RecordNotFound (Couldn't find Upload with 'id'=9947)",
    )
    @store.report(Logger::WARN, "test", "B")
    @store.ignore = [
      /^ActiveRecord::RecordNotFound \(Couldn't find Upload/,
      /^Can't verify CSRF token authenticity/,
    ]
    @store.report(Logger::WARN, "test", "Can't verify CSRF token authenticity")
    @store.report(
      Logger::FATAL,
      "test",
      "ActiveRecord::RecordNotFound (Couldn't find Upload with 'id'=9947)",
    )
    @store.report(
      Logger::FATAL,
      "test",
      "ActiveRecord::RecordNotFound (Couldn't find Upload with 'id'=9489+78946947)",
    )
    @store.report(Logger::WARN, "test", "B")

    assert_equal(4, @store.count)
  end

  def test_ignore_pattern_basic
    @store.ignore = [Logster::IgnorePattern.new(nil, username: "CausingErrors")]
    @store.report(Logger::WARN, "test", "Foobar") #
    @store.report(Logger::WARN, "test", "Foobar", env: { username: "CausingErrors" })
    @store.report(Logger::WARN, "test", "Foobar", env: nil)
    @store.report(Logger::WARN, "test", "Something Else", env: { username: "CausingErrors" })
    @store.report(Logger::WARN, "test", "Something Else", env: { "username" => "CausingErrors" })
    @store.report(Logger::WARN, "test", "Something Else", env: { username: "GoodPerson" }) #
    @store.report(Logger::WARN, "test", "Can't verify CSRF token authenticity") #

    assert_equal(4, @store.count)
  end

  def test_ignore_pattern_real
    @store.ignore = [
      /^ActionController::RoutingError \(No route matches/,
      Logster::IgnorePattern.new(
        "Can't verify CSRF token authenticity",
        REQUEST_URI: %r{/trackback/$},
      ),
    ]
    # blocked
    @store.report(
      Logger::WARN,
      "whatever",
      "Can't verify CSRF token authenticity",
      env: {
        HTTP_HOST: "meta.discourse.org",
        REQUEST_URI: "/t/use-more-standard-smiley-codes-instead-of-smile/1822/trackback/",
        REQUEST_METHOD: "POST",
        HTTP_USER_AGENT: "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)",
        params: {
          title: "Something Spammy",
          url: "http://spam.example.net/whatever/spam.html",
          excerpt: "http://spam.example.com/pdf/blahblah.html free viagra",
          blog_name: "get free spam for cheap",
        },
      },
    )
    # logged
    @store.report(
      Logger::WARN,
      "whatever",
      "Can't verify CSRF token authenticity",
      env: {
        HTTP_HOST: "meta.discourse.org",
        REQUEST_URI: "/session",
        REQUEST_METHOD: "POST",
        HTTP_USER_AGENT:
          "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.1916.153 Safari/537.36",
        params: {
          username: "user",
          password: "password",
          form_authenticity_token: "incorrect",
        },
      },
    )
    assert_equal(1, @store.count)
  end

  def test_timestamp
    time = Time.now - 24 * 60 * 60
    message = @store.report(Logger::WARN, "test", "B", timestamp: time)

    assert_equal(time, message.timestamp)
  end

  def test_backtrace
    # Create an error with a backtrace
    error = TypeError.new
    begin
      raise error
    rescue => e
      error = e
    end

    # Backtrace can be passed via backtrace param or env
    message = @store.report(Logger::WARN, "test", "A", backtrace: error.backtrace)
    assert_equal(error.backtrace.join("\n"), message.backtrace)
    message = @store.report(Logger::WARN, "test", "B", env: { backtrace: error.backtrace })
    assert_equal(error.backtrace.join("\n"), message.backtrace)

    # Via env takes priority
    message =
      @store.report(
        Logger::WARN,
        "test",
        "C",
        backtrace: "Garbage",
        env: {
          backtrace: error.backtrace,
        },
      )
    assert_equal(error.backtrace.join("\n"), message.backtrace)

    # Backtrace is always a string
    # Cannot do an equal assert here, because it uses `caller` when not provided
    message = @store.report(Logger::WARN, "test", "D", backtrace: nil)
    assert_kind_of(String, message.backtrace)
    message = @store.report(Logger::WARN, "test", "E", env: { backtrace: nil })
    assert_kind_of(String, message.backtrace)
    message = @store.report(Logger::WARN, "test", "F", backtrace: nil, env: { backtrace: nil })
    assert_kind_of(String, message.backtrace)
    message = @store.report(Logger::WARN, "test", "G")
    assert_kind_of(String, message.backtrace)

    # Arrays are turned into strings via join \n
    message = @store.report(Logger::WARN, "test", "H", backtrace: %w[Foo Bar])
    assert_equal("Foo\nBar", message.backtrace)
  end

  def test_chained_loggers_dont_have_superfluous_frames_in_backtrace
    logger = Logster::Logger.new(@store)
    other_store = Logster::TestStore.new
    other_logger = Logster::Logger.new(other_store)
    logger.chain(other_logger)
    logger.warn("this is warning")
    [@store, other_store].each do |store|
      message = store.reported.first
      assert_equal("this is warning", message.message)
      # the first line in the backtrace should be the method that
      # called the warn/info/error etc. method.
      # in this case the first line should be this test method
      assert_includes(message.backtrace.lines.first, __method__.to_s)
    end
  end

  def test_log_message_is_truncated_when_above_maximum_message_length
    orig = Logster.config.maximum_message_length
    Logster.config.maximum_message_length = 300
    msg = @store.report(Logger::WARN, "", "a" * 400)
    # 3 is the ... at the end to indicate truncated message
    assert_equal(300 + 3, msg.message.size)

    Logster.config.maximum_message_length = 100
    msg = @store.report(Logger::WARN, "", "a" * 200)
    assert_equal(100 + 3, msg.message.size)
  ensure
    Logster.config.maximum_message_length = orig
  end

  def test_chained_loggers_shouldnt_mutate_env_passed_to_them
    logger = Logster::Logger.new(@store)
    other_store = Logster::TestStore.new
    other_logger = Logster::Logger.new(other_store)
    logger.chain(other_logger)
    logger.add(Logger::WARN, "this is warning", "", { env: { backtrace: "11" } })
    [@store, other_store].each do |store|
      assert_equal("11", store.reported.first.backtrace)
      refute_includes(store.reported.first.env.keys.map(&:to_sym), :backtrace)
    end
  end

  def test_envs_with_invalid_encoding_dont_raise_errors
    msg = @store.report(Logger::WARN, "", "me have invalid encoding", env: { axe: "a\xF1xasa" })
    assert_equal("a�xasa", msg.env[:axe])
  end
end

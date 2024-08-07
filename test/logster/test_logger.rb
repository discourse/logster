# frozen_string_literal: true

require_relative "../test_helper"
require "logster/logger"
require "logger"

class TestStore < Logster::BaseStore
  attr_accessor :calls

  def report(*args)
    (@calls ||= []) << args
  end
end

class TestLogger < Minitest::Test
  def setup
    @store = TestStore.new
    @logger = Logster::Logger.new(@store)
  end

  def test_only_logs_valid_encoding
    @logger.add(4, "a \xE4 test", "prog")
    _, _, message = @store.calls[0]
    assert_equal true, message.valid_encoding?
  end

  def test_per_thread_override
    logger2 = Logster::Logger.new(@store)
    logger2.override_level = 2

    # we should not leak between objects
    assert_nil @logger.override_level

    @logger.override_level = 2

    @logger.add(0, "test", "prog", backtrace: "backtrace", env: { a: "x" })
    Thread.new { @logger.add(0, "test", "prog", backtrace: "backtrace", env: { a: "x" }) }.join

    @logger.override_level = nil
    @logger.add(0, "test", "prog", backtrace: "backtrace", env: { a: "x" })

    assert_equal 2, @store.calls.length
  end

  def test_backtrace
    @logger.add(0, "test", "prog", backtrace: "backtrace", env: { a: "x" })
    assert_equal "backtrace", @store.calls[0][3][:backtrace]
  end

  def test_chain
    io = StringIO.new
    @logger.chain Logger.new(io)
    @logger.warn "boom"

    assert_match(/W,.*boom/, io.string)
  end

  def test_backtrace_with_chain
    @other_store = TestStore.new
    @logger.chain(Logster::Logger.new(@other_store))

    @logger.add(0, "test", "prog", backtrace: "backtrace", env: { a: "x" })

    [@store, @other_store].each { |store| assert_equal "backtrace", store.calls[0][3][:backtrace] }
  end

  def test_add_with_one_argument
    @logger.add(2) { "test" }
    @logger.add(2)
    assert_equal 2, @store.calls.length
    assert_equal "test", @store.calls.first[2]
  end

  def test_subscribing_to_logger_events
    custom_logger_klass =
      Class.new do
        attr_reader :events

        def initialize
          @events = []
        end

        def log(severity, message, progname, opts, &block)
          @events.push({ severity:, message:, progname:, opts:, block: })
        end
      end

    custom_logger = custom_logger_klass.new

    @logger.subscribe do |severity, message, progname, opts, &block|
      custom_logger.log(severity, message, progname, opts, &block)
    end

    @logger.add(0, "test", "prog", backtrace: "backtrace", env: { a: "x" })
    @logger.add(1, nil, nil, backtrace: "backtrace") { "yielded message" }

    first_event = custom_logger.events[0]

    assert_equal(0, first_event[:severity])
    assert_equal("test", first_event[:message])
    assert_equal("prog", first_event[:progname])
    assert_equal({ backtrace: "backtrace", env: { a: "x" } }, first_event[:opts])
    assert_nil first_event[:block]

    second_event = custom_logger.events[1]

    assert_equal(1, second_event[:severity])
    assert_nil second_event[:message]
    assert_nil second_event[:progname]
    assert_equal({ backtrace: "backtrace", env: nil }, second_event[:opts])
    assert_equal("yielded message", second_event[:block].call)
  end

  class NewLogger < Logster::Logger
  end

  def test_inherited_logger_backtrace_with_chain
    @other_store = TestStore.new
    @logger = NewLogger.new(@store)
    @logger.chain(Logster::Logger.new(@other_store))

    @logger.add(0, "test", "prog", backtrace: "backtrace", env: { a: "x" })

    [@store, @other_store].each { |store| assert_equal "backtrace", store.calls[0][3][:backtrace] }
  end

  def test_progname_parameter
    @logger.add(0, "test")
    progname = @store.calls[0][1]
    assert_nil progname
  end

  class PlayLogger
    attr_accessor :skip_store
    def initialize(tester)
      @tester = tester
    end

    def add(s, m, p, &block)
      @tester.assert(skip_store)
    end
  end

  def test_chain_with_ignore
    @logger.chain PlayLogger.new(self)
    @logger.skip_store = true
    @logger.warn("testing")
  end

  def test_logging_an_error_gets_backtrace_from_the_error
    exception = error_instance(Exception)
    std_err = error_instance(StandardError)
    custom_err = error_instance(Class.new(StandardError))

    @logger.error(exception)
    @logger.fatal(std_err)
    @logger.fatal(custom_err)

    assert_equal exception.backtrace.join("\n"), @store.calls[0][3][:backtrace]
    assert_equal std_err.backtrace.join("\n"), @store.calls[1][3][:backtrace]
    assert_equal custom_err.backtrace.join("\n"), @store.calls[2][3][:backtrace]
  end

  def test_formatter
    @logger.formatter = ->(severity, datetime, progname, msg) { "[test] #{msg}" }
    @logger.add(0, "hello")
    assert_equal "[test] hello", @store.calls[0][2]
  end

  private

  def error_instance(error_class)
    raise error_class.new
  rescue error_class => e
    e
  end
end

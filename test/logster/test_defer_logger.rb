# frozen_string_literal: true

require_relative '../test_helper'
require 'logster/defer_logger'
require 'logster/logger'

class TestDeferLogger < Minitest::Test
  def setup
    @store = TestStore.new
    @defer_logger = Logster::DeferLogger.new(@store)
  end

  def test_defer_logger_inherits_logger
    assert(Logster::Logger === @defer_logger)
  end

  def test_work_is_done_async
    queue = Logster::Scheduler.queue
    assert_equal(0, queue.size)

    @defer_logger.add(4, "hi this a test", "prog")

    assert_equal(1, queue.size)
    queue << :terminate
    Logster::Scheduler.thread.join
    assert_equal(1, @store.calls.size)

    # we need to make sure the backtrace is passed from the main thread.
    # Otherwise we'd only get a partial backtrace from
    # the point the new thread was spawned
    backtrace = @store.calls.first[3][:backtrace]
    assert_includes(backtrace.lines.first, __method__.to_s)

    assert_equal(0, queue.size)
  end
end

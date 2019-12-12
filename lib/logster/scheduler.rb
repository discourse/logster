# frozen_string_literal: true

module Logster
  module Deferer
    attr_reader :queue, :thread
    def initialize
      @queue = Queue.new
      @mutex = Mutex.new
      @thread = nil
      @enabled = true
    end

    def disable
      @enabled = false
    end

    def enable
      @enabled = true
    end

    def schedule(&blk)
      if @enabled
        start_thread if !@thread&.alive?
        @queue << blk
      else
        return if blk == :terminate
        blk.call
      end
    end

    private

    def start_thread
      @mutex.synchronize do
        if !@thread&.alive?
          @thread = Thread.new { do_work }
        end
      end
    end

    def do_work
      while true
        blk = @queue.pop
        # we need to be able to break the loop so that the new
        # thread "finishes" and let us test this code.
        break if blk == :terminate
        blk.call
      end
    end
  end

  class Scheduler
    extend Deferer
    initialize
  end
end

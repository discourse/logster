# frozen_string_literal: true

require "logger"

module Logster
  class Logger < ::Logger
    LOGSTER_ENV = "logster_env"

    attr_accessor :store, :skip_store
    attr_reader :chained

    def initialize(store)
      super(nil)
      @store = store
      @chained = []
      @subscribers = []
      @skip_store = false
      @logster_override_level_key = "logster_override_level_#{object_id}"
    end

    def override_level=(val)
      Thread.current[@logster_override_level_key] = val
    end

    def override_level
      Thread.current[@logster_override_level_key]
    end

    def chain(logger)
      @chained << logger
    end

    ##
    # Subscribe to log events.
    #
    # Example:
    #   logger.subscribe do |severity, message, progname, opts, &block|
    #     YourCustomLogger.log(severity, message, progname, opts, &block)
    #   end
    def subscribe(&block)
      @subscribers << block
    end

    def add_to_chained(logger, severity, message, progname, opts = nil, &block)
      if logger.respond_to? :skip_store
        old = logger.skip_store
        logger.skip_store = @skip_store
      end

      if logger.is_a?(Logster::Logger)
        logger.add(severity, message, progname, opts, &block)
      else
        logger.add(severity, message, progname, &block)
      end
    ensure
      logger.skip_store = old if logger.respond_to? :skip_store
    end

    def add(*args, &block)
      add_with_opts(*args, &block)
    end

    def level
      Thread.current[@logster_override_level_key] || @level
    end

    def add_with_opts(severity, message = nil, progname = progname(), opts = nil, &block)
      return true if severity < level

      # it is not fun losing messages cause encoding is bad
      # protect all messages by scrubbing if needed
      message = message.scrub if message && !message.valid_encoding?

      # we want to get the backtrace as early as possible so that logster's
      # own methods don't show up as the first few frames in the backtrace
      if !opts || !opts.key?(:backtrace)
        opts ||= {}
        backtrace = message.backtrace if message.kind_of?(::Exception)
        backtrace ||= progname.backtrace if progname.kind_of?(::Exception)
        if !backtrace
          backtrace = caller_locations
          backtrace.shift while backtrace.first.path.end_with?("/logger.rb")
        end
        backtrace = backtrace.join("\n")
        opts[:backtrace] = backtrace
      end

      notify_subscribers(severity, message, progname, opts, &block)
      add_to_chained_loggers(severity, message, progname, opts, &block)

      return if @skip_store

      progname ||= @progname
      if message.nil?
        if block_given?
          message = yield
        else
          message = progname
          progname = @progname
        end
      end

      message = formatter.call(severity, Time.now, progname, message) if formatter

      opts ||= {}
      opts[:env] ||= Thread.current[LOGSTER_ENV]

      report_to_store(severity, progname, message, opts)
    rescue => e
      # don't blow up if STDERR is somehow closed
      begin
        STDERR.puts "Failed to report error: #{e} #{severity} #{message} #{progname}"
      rescue StandardError
        nil
      end
    end

    private

    def add_to_chained_loggers(severity, message, progname, opts, &block)
      chained_length = @chained.length

      if chained_length > 0
        i = 0
        # micro optimise for logging since while loop is almost twice as fast
        while i < chained_length
          begin
            add_to_chained(@chained[i], severity, message, progname, opts, &block)
          rescue => e
            # don't blow up if STDERR is somehow closed
            begin
              STDERR.puts "Failed to report message to chained logger: #{e.class} (#{e.message})\n#{e.backtrace.join("\n")}"
            rescue StandardError
              nil
            end
          end
          i += 1
        end
      end
    end

    def notify_subscribers(severity, message, progname, opts, &block)
      subscribers_length = @subscribers.length

      if subscribers_length > 0
        i = 0

        # micro optimise for logging since while loop is almost twice as fast
        while i < subscribers_length
          begin
            @subscribers[i].call(severity, message, progname, opts, &block)
          rescue => e
            # don't blow up if STDERR is somehow closed
            begin
              STDERR.puts "Failed to report message to subscriber: #{e.class} (#{e.message})\n#{e.backtrace.join("\n")}"
            rescue StandardError
              nil
            end
          end

          i += 1
        end
      end
    end

    def report_to_store(severity, progname, message, opts = {})
      @store.report(severity, progname, message, opts)
    end
  end
end

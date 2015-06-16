require 'logger'

module Logster
  class Logger < ::Logger
    LOGSTER_ENV = "logster_env".freeze

    attr_accessor :store, :skip_store

    def initialize(store)
      super(nil)
      @store = store
    end

    def chain(logger)
      @chained ||= []
      @chained << logger
    end

    def add_to_chained(logger, severity, message, progname, &block)
      old = nil
      if logger.respond_to? :skip_store
        old = logger.skip_store
        logger.skip_store = @skip_store
      end

      logger.add(severity, message, progname, &block)

    ensure
      if logger.respond_to? :skip_store
        logger.skip_store = old
      end
    end


    def add(severity, message, progname, &block)
      if severity < @level
        return true
      end

      if @chained
        i = 0
        # micro optimise for logging
        while i < @chained.length
          # TODO double yielding blocks
          begin
            add_to_chained(@chained[i], severity, message, progname, &block)
          rescue => e
            # don't blow up if STDERR is somehow closed
            STDERR.puts "Failed to report message to chained logger #{e}" rescue nil
          end
          i += 1
        end
      end

      progname ||= @progname
      if message.nil?
        if block_given?
          message = yield
        else
          message = progname
          progname = @progname
        end
      end

      return if @skip_store

      @store.report(severity, progname, message, {
        env: Thread.current[LOGSTER_ENV]
      })

    rescue => e
      # don't blow up if STDERR is somehow closed
      STDERR.puts "Failed to report error: #{e} #{severity} #{message} #{progname}" rescue nil
    end
  end
end

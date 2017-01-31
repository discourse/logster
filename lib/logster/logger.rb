require 'logger'

module Logster
  class Logger < ::Logger
    LOGSTER_ENV = "logster_env".freeze

    attr_accessor :store, :skip_store

    def initialize(store)
      super(nil)
      @store = store
      @override_levels = nil
    end

    def override_level=(val)
      tid = Thread.current.object_id

      ol = @override_levels
      if val.nil? && ol && ol.key?(tid)
        ol.delete(tid)
        @override_levels = nil if ol.length == 0
      elsif val
        (@override_levels ||= {})[tid] = val
      end
    end

    def chain(logger)
      @chained ||= []
      @chained << logger
    end

    def add_to_chained(logger, severity, message, progname, opts=nil, &block)
      if logger.respond_to? :skip_store
        old = logger.skip_store
        logger.skip_store = @skip_store
      end

      if logger.is_a?(self.class)
        logger.add(severity, message, progname, opts, &block)
      else
        logger.add(severity, message, progname, &block)
      end
    ensure
      if logger.respond_to? :skip_store
        logger.skip_store = old
      end
    end

    def add(*args, &block)
      add_with_opts(*args,&block)
    end

    def level
      ol = @override_levels
      (ol && ol[Thread.current.object_id]) || @level
    end

    def add_with_opts(severity, message, progname, opts=nil, &block)
      if severity < level
        return true
      end

      if @chained
        i = 0
        # micro optimise for logging
        while i < @chained.length
          # TODO double yielding blocks
          begin
            add_to_chained(@chained[i], severity, message, progname, opts, &block)
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

      opts ||= {}
      opts[:env] ||= Thread.current[LOGSTER_ENV]

      @store.report(severity, progname, message, opts)

    rescue => e
      # don't blow up if STDERR is somehow closed
      STDERR.puts "Failed to report error: #{e} #{severity} #{message} #{progname}" rescue nil
    end
  end
end

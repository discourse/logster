require 'logger'

module Logster
  class Logger < ::Logger
    attr_accessor :store

    def initialize(store)
      super(nil)
      @store = store
    end

    def chain(logger)
      @chained ||= []
      @chained << logger
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
          @chained[i].add(severity, message, progname, &block)
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

      @store.report(severity, progname, message)

    end
  end
end

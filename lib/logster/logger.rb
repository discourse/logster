require 'logger'

module Logster
  class Logger < ::Logger
    attr_accessor :store

    def initialize(store)
      super(nil)
      @store = store
    end

    def add(severity, message, progname, &block)
      if severity < @level
        return true
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

module Logster
  class Logger < ::Logger
    def initialize(backend)
      super(nil)
      @backend = backend
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

     @backend.report(severity, progname, message)

    end
  end
end

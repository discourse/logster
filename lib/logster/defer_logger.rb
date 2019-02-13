require 'logster/scheduler'

module Logster
  class DeferLogger < ::Logster::Logger
    private

    def report_to_store(severity, progname, message, opts = {})
      opts[:backtrace] ||= caller
      Logster::Scheduler.schedule do
        super(severity, progname, message, opts)
      end
    end
  end
end

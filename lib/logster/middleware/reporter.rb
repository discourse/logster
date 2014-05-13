module Logster
  module Middleware
    class Reporter

      PATH_INFO = "PATH_INFO".freeze

      def initialize(app, config={})
        @app = app
        @error_path = (Logster.config.subdirectory || '/logs') + '/report_js_error'
      end

      def call(env)
        Thread.current[Logster::Logger::LOGSTER_ENV] = env

        path = env[PATH_INFO]
        if path == @error_path
          return report_js_error(env)
        end

        @app.call(env)
      ensure
        Thread.current[Logster::Logger::LOGSTER_ENV] = nil
      end

      def report_js_error(env)
        req = Rack::Request.new(env)
        message = req["message"] || ""
        message << "\nUrl: " << req["url"] if req["url"]
        message << "\nLine: " << req["line"] if req["line"]
        message << "\nColumn: " << req["column"] if req["column"]

        backtrace = req["stacktrace"] || ""
        Logster.store.report(::Logger::Severity::WARN,
                            "javascript",
                            message,
                            backtrace: backtrace,
                            env: env)
        [200,{},["OK"]]
      end

    end
  end
end

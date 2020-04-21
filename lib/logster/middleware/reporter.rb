# frozen_string_literal: true

module Logster
  module Middleware
    class Reporter

      PATH_INFO = "PATH_INFO"
      SCRIPT_NAME = "SCRIPT_NAME"

      def initialize(app, config = {})
        @app = app
        @error_path = Logster.config.subdirectory + '/report_js_error'
      end

      def call(env)
        Thread.current[Logster::Logger::LOGSTER_ENV] = env

        path = env[PATH_INFO]
        script_name = env[SCRIPT_NAME]

        if script_name && script_name.length > 0
          path = script_name + path
        end

        if path == @error_path

          if !Logster.config.enable_js_error_reporting
            return [403, {}, ["Access Denied"]]
          end

          Logster.config.current_context.call(env) do
            if Logster.config.rate_limit_error_reporting
              req = Rack::Request.new(env)
              if Logster.store.rate_limited?(req.ip, perform: true)
                return [429, {}, ["Rate Limited"]]
              end
            end
            report_js_error(env)
          end
          return [200, {}, ["OK"]]
        end

        @app.call(env)
      ensure
        Thread.current[Logster::Logger::LOGSTER_ENV] = nil
      end

      def report_js_error(env)
        req = Rack::Request.new(env)

        params = req.params

        message = (params["message"] || "").dup
        message << "\nUrl: " << params["url"] if params["url"]
        message << "\nLine: " << params["line"] if params["line"]
        message << "\nColumn: " << params["column"] if params["column"]
        message << "\nWindow Location: " << params["window_location"] if params["window_location"]

        backtrace = params["stacktrace"] || ""

        severity = ::Logger::Severity::WARN
        if params["severity"] &&
           ::Logger::Severity.const_defined?(params["severity"].upcase)
          severity = ::Logger::Severity.const_get(params["severity"].upcase)
        end

        Logster.store.report(severity,
                            "javascript",
                            message,
                            backtrace: backtrace,
                            env: env)

        true
      end

    end
  end
end

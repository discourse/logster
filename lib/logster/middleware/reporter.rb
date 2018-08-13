module Logster
  module Middleware
    class Reporter

      PATH_INFO = "PATH_INFO".freeze
      SCRIPT_NAME = "SCRIPT_NAME".freeze

      def initialize(app, config={})
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
          Logster.config.current_context.call(env) do
            report_js_error(env)
          end
          return [200,{},["OK"]]
        end

        @app.call(env)
      ensure
        Thread.current[Logster::Logger::LOGSTER_ENV] = nil
      end

      def report_js_error(env)
        req = Rack::Request.new(env)
        params = req.params

        message = params["message"] || ""
        message << "\nUrl: " << params["url"] if params["url"]
        message << "\nLine: " << params["line"] if params["line"]
        message << "\nColumn: " << params["column"] if params["column"]
        message << "\nWindow Location: " << params["window_location"] if params["window_location"]

        backtrace = params["stacktrace"] || ""
        Logster.store.report(::Logger::Severity::WARN,
                            "javascript",
                            message,
                            backtrace: backtrace,
                            env: env)
      end

    end
  end
end

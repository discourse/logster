# frozen_string_literal: true

module Logster
  module Middleware
    class Reporter
      PATH_INFO = "PATH_INFO"
      SCRIPT_NAME = "SCRIPT_NAME"
      REQUEST_METHOD = "REQUEST_METHOD"
      SECURITY_HEADERS = {
        "cache-control" => "no-store",
        "referrer-policy" => "no-referrer",
        "x-content-type-options" => "nosniff",
      }.freeze

      def initialize(app, config = {})
        @app = app
        @error_path = Logster.config.subdirectory + "/report_js_error"
      end

      def call(env)
        Thread.current[Logster::Logger::LOGSTER_ENV] = env

        path = env[PATH_INFO]
        script_name = env[SCRIPT_NAME]

        path = script_name + path if script_name && script_name.length > 0

        if path == @error_path
          if env[REQUEST_METHOD] != "POST"
            return response(405, "Method not allowed", "allow" => "POST")
          end
          return response(403, "CSRF validation failed") unless valid_csrf_request?(env)
          return response(403, "Access Denied") if !Logster.config.enable_js_error_reporting

          Logster
            .config
            .current_context
            .call(env) do
              if Logster.config.rate_limit_error_reporting
                req = Rack::Request.new(env)
                if Logster.store.rate_limited?(req.ip, perform: true)
                  return response(429, "Rate Limited")
                end
              end
              report_js_error(env)
            end
          return response(200, "OK")
        end

        @app.call(env)
      ensure
        Thread.current[Logster::Logger::LOGSTER_ENV] = nil
      end

      def response(status, body, headers = {})
        [
          status,
          SECURITY_HEADERS.merge("content-type" => "text/plain; charset=utf-8").merge(headers),
          [body],
        ]
      end

      def valid_csrf_request?(env)
        fetch_site = env["HTTP_SEC_FETCH_SITE"]
        return false if fetch_site && !%w[same-origin same-site none].include?(fetch_site)

        same_origin_fetch = fetch_site == "same-origin"
        ajax_request = env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
        return false unless same_origin_fetch || ajax_request
        return true if same_origin_fetch

        origin = env["HTTP_ORIGIN"]
        !origin || origin == Rack::Request.new(env).base_url
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
        if params["severity"] && ::Logger::Severity.const_defined?(params["severity"].upcase)
          severity = ::Logger::Severity.const_get(params["severity"].upcase)
        end

        Logster.store.report(severity, "javascript", message, backtrace: backtrace, env: env)

        true
      end
    end
  end
end

class Logster::Middleware::DebugExceptions < ActionDispatch::DebugExceptions
  private

  def log_error(request_or_env, wrapper)
    env =
      if Rails::VERSION::MAJOR > 4
        request_or_env.env
      else
        request_or_env
      end

    exception = wrapper.exception

    Logster.config.current_context.call(env) do
      location = exception.backtrace[0]
      exception_string = exception.to_s

      Logster.logger.add_with_opts(::Logger::Severity::FATAL,
                        exception.class.to_s << " (" << exception_string << ")\n#{location}",
                        "web-exception",
                        backtrace: exception.backtrace.join("\n"),
                        env: env)
    end

  end
end

class Logster::Middleware::DebugExceptions < ActionDispatch::DebugExceptions
  private

  def log_error(request_or_env, wrapper)
    is_request = Rails::VERSION::MAJOR > 4
    env = is_request ? request_or_env.env : request_or_env
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

    super(request_or_env, wrapper) if is_request
  end
end

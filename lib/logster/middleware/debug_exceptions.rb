class Logster::Middleware::DebugExceptions < ActionDispatch::DebugExceptions
  private

  def log_error(env,wrapper)
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

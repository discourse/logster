class Logster::Middleware::DebugExceptions < ActionDispatch::DebugExceptions
  private

  def log_error(env,wrapper)
    Logster.logger.skip_store = true
    exception = wrapper.exception

    Logster.config.current_context.call(env) do
       Logster.store.report(::Logger::Severity::FATAL,
                        "web",
                        exception.class.to_s << " (" << exception.to_s << ")",
                        backtrace: exception.backtrace.join("\n"),
                        env: env)
    end
    super(env, wrapper)
  ensure
    Logster.logger.skip_store = false
  end
end

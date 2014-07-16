class SidekiqLogsterReporter
  def call(ex, context={})
    # Pass context to Logster
    fake_env = {}
    context.each do |key, value|
      Logster.add_to_env(fake_env, key, value)
    end

    text = "Job exception: #{ex}\n"
    if ex.backtrace
      Logster.add_to_env(fake_env, :backtrace, ex.backtrace)
    end

    Thread.current[Logster::Logger::LOGSTER_ENV] = fake_env
    Logster.logger.error(text)
  rescue => e
    Logster.logger.fatal("Failed to log exception #{ex} #{hash}\nReason: #{e.class} #{e}\n#{e.backtrace.join("\n")}")
  ensure
    Thread.current[Logster::Logger::LOGSTER_ENV] = nil
  end
end

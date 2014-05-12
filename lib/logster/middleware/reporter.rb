module Logster
  module Middleware
    class Reporter

      def initialize(app, config={})
        @app = app
      end

      def call(env)
        Thread.current[Logster::Logger::LOGSTER_ENV] = env
        @app.call(env)
      ensure
        Thread.current[Logster::Logger::LOGSTER_ENV] = nil
      end
    end
  end
end

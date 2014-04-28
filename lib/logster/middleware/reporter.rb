module Logster
  module Middleware
    class Reporter
      def initialize(app, config={})
        @app = app
      end

      def call(env)
        @app.call(env)
      end
    end
  end
end

module Logster
  module Middleware
    class Viewer
      def initialize(app, config={})
        @app = app
      end

      def call(env)
        @app.call(env)
      end
    end
  end
end

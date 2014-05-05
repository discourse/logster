require 'json'

module Logster
  module Middleware
    class Viewer

      PATH_INFO = "PATH_INFO".freeze

      def initialize(app, config)
        @app = app
        @logs_path = config[:path] || "/logs"
        @path_regex = Regexp.new("(#{@logs_path}$)|(#{@logs_path}(/.*))$")

        @store = config[:store] or raise ArgumentError.new("store")

        @assets_path = File.expand_path("../../../../assets", __FILE__)
        @fileserver = Rack::File.new(@assets_path)
      end

      def call(env)
        path = env[PATH_INFO]

        if resource = resolve_path(path)

          if resource =~ /\.js$|\.handlebars$|\.css$/
            env[PATH_INFO] = resource
            @fileserver.call(env)
          elsif resource.start_with?("/messages.json")
            serve_messages(Rack::Request.new(env))
          elsif resource == "/"
            [200, {"Content-Type" => "text/html; charset=utf-8"}, [body(preload_json)]]
          else
            [404, {}, ["Not found"]]
          end
        else
          @app.call(env)
        end
      end

      protected

      def serve_messages(req)
        opts = {
          before: req["before"],
          after: req["after"],
          regex: req["regex"]
        }

        if(filter = req["filter"])
          filter = filter.split("_").map{|s| s.to_i}
          opts[:severity] = filter
        end

        if search = req["search"]
          opts[:search] = search
        end

        payload = {
          messages: @store.latest(opts),
          total: @store.count
        }

        json = JSON.generate(payload)
        [200, {"Content-Type" => "application/json"}, [json]]
      end

      def resolve_path(path)
        if path =~ @path_regex
          $3 || "/"
        end
      end

      def preload_json
      end

      def css(name, attrs={})
        attrs = attrs.map do |k,v|
          "#{k}='#{v}'"
        end.join(" ")

        "<link rel='stylesheet' type='text/css' href='#{@logs_path}/stylesheets/#{name}' #{attrs}>"
      end

      def script(prod, dev=nil)
        name = ENV['DEBUG_JS'] == "1" && dev ? dev : prod
        "<script src='#{@logs_path}/javascript/#{name}'></script>"
      end

      def handlebars(name)
        val = File.read("#{@assets_path}/javascript/templates/#{name}.handlebars")
<<JS
      <script>
        Ember.TEMPLATES[#{name.inspect}] = Ember.Handlebars.compile(#{val.inspect});
      </script>
JS
      end

      def body(preload)
<<HTML
<html>
<head>
  #{css("app.css")}
  #{script("external/moment.min.js")}
  #{script("external/jquery.min.js")}
  #{script("external/handlebars.min.js")}
  #{script("external/lodash.min.js")}
  #{script("external/ember.min.js", "external/ember.js")}
  #{handlebars("application")}
  #{handlebars("index")}
  #{handlebars("message")}
  <script>
    window.Logger = {
       rootPath: "#{@logs_path}"
    };
  </script>
</head>
<body>
  #{script("app.js")}
</body>
</html>
HTML
      end

    end
  end

end

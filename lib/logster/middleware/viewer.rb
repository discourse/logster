require 'json'

module Logster
  module Middleware
    class Viewer

      PATH_INFO = "PATH_INFO".freeze
      SCRIPT_NAME = "SCRIPT_NAME".freeze

      def initialize(app)
        @app = app

        @logs_path = Logster.config.subdirectory || "/logs"
        @path_regex = Regexp.new("^(#{@logs_path}$)|^(#{@logs_path}(/.*))$")
        @store = Logster.store or raise ArgumentError.new("store")

        @assets_path = File.expand_path("../../../../assets", __FILE__)
        @fileserver = Rack::File.new(@assets_path)
      end

      def call(env)
        path = env[PATH_INFO]
        script_name = env[SCRIPT_NAME]

        if script_name && script_name.length > 0
          path = script_name + path
        end

        if resource = resolve_path(path)

          return @app.call(env) if !Logster.config.authorize_callback.call(env)

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
          after: req["after"]
        }

        if(filter = req["filter"])
          filter = filter.split("_").map{|s| s.to_i}
          opts[:severity] = filter
        end

        if search = req["search"]
          search = (parse_regex(search) || search) if req["regex_search"] == "true"
          opts[:search] = search
        end

        payload = {
          messages: @store.latest(opts),
          total: @store.count
        }

        json = JSON.generate(payload)
        [200, {"Content-Type" => "application/json"}, [json]]
      end

      def parse_regex(string)
        if string =~ /\/(.+)\/(.*)/
          s = $1
          flags = Regexp::IGNORECASE if $2 && $2.include?("i")
          Regexp.new(s, flags) rescue nil
        end
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

      def component(name)
        ember_template("components/#{name}", "components/" << name)
      end

      def handlebars(name)
        ember_template("templates/#{name}", name)
      end

      def ember_template(location, name)
        val = File.read("#{@assets_path}/javascript/#{location}.handlebars")
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
  #{component("tabbed-section")}
  #{component("tab-contents")}
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

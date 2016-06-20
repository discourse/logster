require 'json'

module Logster
  module Middleware
    class Viewer

      PATH_INFO = "PATH_INFO".freeze
      SCRIPT_NAME = "SCRIPT_NAME".freeze
      REQUEST_METHOD = "REQUEST_METHOD".freeze

      def initialize(app)
        @app = app

        @logs_path = Logster.config.subdirectory
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

          if resource =~ /\.ico$|\.js$|\.png|\.handlebars$|\.css$|\.woff$|\.ttf$|\.woff2$|\.svg$|\.otf$|\.eot$/
            env[PATH_INFO] = resource
            # accl redirect is going to be trouble, ensure its bypassed
            env['sendfile.type'] = ''
            @fileserver.call(env)

          elsif resource.start_with?("/messages.json")
            serve_messages(Rack::Request.new(env))

          elsif resource =~ /\/message\/([0-9a-f]+)$/
            if env[REQUEST_METHOD] != "DELETE"
              return [405, {}, ["GET not allowed for /clear"]]
            end

            key = $1
            message = Logster.store.get(key)
            unless message
              return [404, {}, ["Message not found"]]
            end

            Logster.store.delete(message)
            return [301, {"Location" => "#{@logs_path}/"}, []]

          elsif resource =~ /\/(un)?protect\/([0-9a-f]+)$/
            off = $1 == "un"
            key = $2

            message = Logster.store.get(key)
            unless message
              return [404, {}, ["Message not found"]]
            end

            if off
              if Logster.store.unprotect(key)
                return [301, {"Location" => "#{@logs_path}/show/#{key}?protected=false"}, []]
              else
                return [500, {}, ["Failed"]]
              end
            else
              if Logster.store.protect(key)
                return [301, {"Location" => "#{@logs_path}/show/#{key}?protected=true"}, []]
              else
                return [500, {}, ["Failed"]]
              end
            end

          elsif resource =~ /\/solve\/([0-9a-f]+)$/
            key = $1

            message = Logster.store.get(key)
            unless message
              return [404, {}, ["Message not found"]]
            end

            Logster.store.solve(key)

            return [301, {"Location" => "#{@logs_path}"}, []]

          elsif resource =~ /\/clear$/
            if env[REQUEST_METHOD] != "POST"
              return [405, {}, ["GET not allowed for /clear"]]
            end
            Logster.store.clear
            return [200, {}, ["Messages cleared"]]

          elsif resource =~ /\/show\/([0-9a-f]+)(\.json)?$/
            key = $1
            json = $2 == ".json"

            message = Logster.store.get(key)
            unless message
              return [404, {}, ["Message not found"]]
            end

            if json
              [200, {"Content-Type" => "application/json; charset=utf-8"}, [message.to_json]]
            else
              preload = preload_json({"/show/#{key}.json" => message})
              [200, {"Content-Type" => "text/html; charset=utf-8"}, [body(preload)]]
            end

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

      def preload_json(extra={})
        values = {}
        values.merge!(extra)
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

      def template(name)
        ember_template("templates/#{name}", name)
      end

      def ember_template(location, name)
        val = File.read("#{@assets_path}/javascript/#{location}.hbs")
<<JS
      <script>
        Ember.TEMPLATES[#{name.inspect}] = Ember.Handlebars.compile(#{val.inspect});
      </script>
JS
      end

      def body(preload)
<<HTML
<!doctype html>
<html>
<head>
  <link rel="shortcut icon" href="#{@logs_path}/images/icon_64x64.png">
  <link rel="apple-touch-icon" href="#{@logs_path}/images/icon_144x144.png" />
  <title>#{Logster.config.web_title || "Logs"}</title>
  <link href='//fonts.googleapis.com/css?family=Roboto' rel='stylesheet' type='text/css'>
  <link href='//fonts.googleapis.com/css?family=Roboto+Mono' rel='stylesheet' type='text/css'>
  #{css("app.css")}
  #{css("font-awesome.min.css")}
  #{script("external/moment.min.js")}
  #{script("external/jquery.min.js")}
  #{script("external/lodash.min.js")}
  #{script("external/ember-template-compiler.js")}
  #{script("external/ember.min.js", "external/ember.js")}
  #{template("application")}
  #{component("message-row")}
  #{component("message-info")}
  #{component("tabbed-section")}
  #{component("tab-contents")}
  #{component("tab-link")}
  #{component("panel-resizer")}
  #{template("index")}
  #{template("show")}
  <script>
    window.Logger = {
       rootPath: "#{@logs_path}",
       preload: #{JSON.fast_generate(preload).gsub("</", "<\\/")}
    };
  </script>
</head>
<body>
  #{script("app.js")}
  <script>
    App.Router.reopen({
      rootURL: Logger.rootPath,
      location: 'history'
    });
  </script>
</body>
</html>
HTML
      end

    end
  end

end

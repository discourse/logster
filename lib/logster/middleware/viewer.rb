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
        (@store = Logster.store) || raise(ArgumentError.new("store"))

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
            serve_file(env, resource)

          elsif resource.start_with?("/messages.json")
            serve_messages(Rack::Request.new(env))

          elsif resource =~ /\/message\/([0-9a-f]+)$/
            if env[REQUEST_METHOD] != "DELETE"
              return method_not_allowed("DELETE is needed for /clear")
            end

            key = $1
            message = Logster.store.get(key)
            unless message
              return [404, {}, ["Message not found"]]
            end

            Logster.store.delete(message)
            return [301, { "Location" => "#{@logs_path}/" }, []]

          elsif resource =~ /\/(un)?protect\/([0-9a-f]+)$/
            off = $1 == "un"
            key = $2

            message = Logster.store.get(key)
            unless message
              return [404, {}, ["Message not found"]]
            end

            if off
              if Logster.store.unprotect(key)
                return [301, { "Location" => "#{@logs_path}/show/#{key}?protected=false" }, []]
              else
                return [500, {}, ["Failed"]]
              end
            else
              if Logster.store.protect(key)
                return [301, { "Location" => "#{@logs_path}/show/#{key}?protected=true" }, []]
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

            return [301, { "Location" => "#{@logs_path}" }, []]

          elsif resource =~ /\/clear$/
            if env[REQUEST_METHOD] != "POST"
              return method_not_allowed("POST is needed for /clear")
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
              [200, { "Content-Type" => "application/json; charset=utf-8" }, [message.to_json]]
            else
              preload = preload_json("/show/#{key}" => message)
              [200, { "Content-Type" => "text/html; charset=utf-8" }, [body(preload)]]
            end

          elsif resource =~ /\/settings(\.json)?$/
            json = $1 == ".json"
            if json
              coded_patterns = Logster.store.ignore&.map(&:inspect) || []
              custom_patterns = Logster::SuppressionPattern.find_all(raw: true)
              [200, { "Content-Type" => "application/json; charset=utf-8" }, [JSON.generate(coded_patterns: coded_patterns, custom_patterns: custom_patterns)]]
            else
              [200, { "Content-Type" => "text/html; charset=utf-8" }, [body(preload_json)]]
            end
          elsif resource =~ /\/patterns\/([a-zA-Z0-9_]+)\.json$/
            unless Logster.config.enable_custom_patterns_via_ui
              return not_allowed("Custom patterns via the UI is disabled. You can enable it by committing this line to your app source code:\nLogster.config.enable_custom_patterns_via_ui = true")
            end

            set_name = $1
            req = Rack::Request.new(env)
            return method_not_allowed if req.request_method == "GET"

            update_patterns(set_name, req)
          elsif resource == "/"
            [200, { "Content-Type" => "text/html; charset=utf-8" }, [body(preload_json)]]
          else
            not_found
          end
        else
          @app.call(env)
        end
      end

      protected

      def serve_file(env, path)
        env[PATH_INFO] = path
        # accl redirect is going to be trouble, ensure its bypassed
        env['sendfile.type'] = ''
        @fileserver.call(env)
      end

      def serve_messages(req)
        params = req.params

        opts = {
          before: params["before"],
          after: params["after"]
        }

        if (filter = params["filter"])
          filter = filter.split("_").map { |s| s.to_i }
          opts[:severity] = filter
        end

        if search = params["search"]
          search = (parse_regex(search) || search) if params["regex_search"] == "true"
          opts[:search] = search
        end

        payload = {
          messages: @store.latest(opts),
          total: @store.count,
          search: params['search'] || '',
          filter: filter || '',
        }

        json = JSON.generate(payload)
        [200, { "Content-Type" => "application/json" }, [json]]
      end

      def update_patterns(set_name, req)
        klass = get_class(set_name)
        return not_found("Unknown set name") unless klass

        request_method = req.request_method
        pattern = req.params["pattern"]

        record = request_method == "POST" ? klass.new(pattern) : klass.find(pattern)
        return not_found unless record

        case request_method
        when "POST"
          record.save
        when "PUT"
          record.modify(req.params["new_pattern"])
        when "DELETE"
          record.destroy
        else
          return method_not_allowed("Allowed methods: POST, PUT or DELETE")
        end

        [200, { "Content-Type" => "application/json" }, [JSON.generate(pattern: record.to_s)]]
      rescue => err
        error_message = err.message

        unless Logster::Pattern::PatternError === err # likely a bug, give us the backtrace
          error_message += "\n\n#{err.backtrace.join("\n")}"
          return [500, {}, [error_message]]
        end

        [400, {}, [error_message]]
      end

      def get_class(set_name)
        case set_name
        when "suppression"
          Logster::SuppressionPattern
        else
          nil
        end
      end

      def not_found(message = "Not found")
        [404, {}, [message]]
      end

      def not_allowed(message = "Not allowed")
        [403, {}, [message]]
      end

      def method_not_allowed(message = "Method not allowed")
        [405, {}, [message]]
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

      def preload_json(extra = {})
        values = {}
        values.merge!(extra)
      end

      def css(name, attrs = {})
        attrs = attrs.map do |k, v|
          "#{k}='#{v}'"
        end.join(" ")

        "<link rel='stylesheet' type='text/css' href='#{@logs_path}/stylesheets/#{name}' #{attrs}>"
      end

      def script(prod, dev = nil)
        name = ENV['DEBUG_JS'] == "1" && dev ? dev : prod
        "<script src='#{@logs_path}/javascript/#{name}'></script>"
      end

      def to_json_and_escape(payload)
        Rack::Utils.escape_html(JSON.fast_generate(payload))
      end

      def body(preload)
        root_url = @logs_path
        root_url += "/" if root_url[-1] != "/"
        preload.merge!(
          env_expandable_keys: Logster.config.env_expandable_keys,
          patterns_enabled: Logster.config.enable_custom_patterns_via_ui
        )
        <<~HTML
          <!doctype html>
          <html>
            <head>
              <link rel="shortcut icon" href="#{@logs_path}/images/icon_64x64.png">
              <link rel="apple-touch-icon" href="#{@logs_path}/images/icon_144x144.png" />
              <title>#{Logster.config.web_title || "Logs"}</title>
              <link href='//fonts.googleapis.com/css?family=Roboto' rel='stylesheet' type='text/css'>
              <link href='//fonts.googleapis.com/css?family=Roboto+Mono' rel='stylesheet' type='text/css'>
              <meta name="viewport" content="width=device-width, minimum-scale=1.0, maximum-scale=1.0, user-scalable=yes">
              #{css("vendor.css")}
              #{css("client-app.css")}
              #{script("vendor.js")}
              <meta id="preloaded-data" data-root-path="#{@logs_path}" data-preloaded="#{to_json_and_escape(preload)}">
              <meta name="client-app/config/environment" content="%7B%22modulePrefix%22%3A%22client-app%22%2C%22environment%22%3A%22production%22%2C%22rootURL%22%3A%22#{root_url}%22%2C%22locationType%22%3A%22history%22%2C%22EmberENV%22%3A%7B%22FEATURES%22%3A%7B%7D%2C%22EXTEND_PROTOTYPES%22%3A%7B%22Date%22%3Afalse%7D%7D%2C%22APP%22%3A%7B%22name%22%3A%22client-app%22%2C%22version%22%3A%220.0.0+8c60a18b%22%7D%2C%22exportApplicationGlobal%22%3Afalse%7D" />
            </head>
            <body>
              #{script("client-app.js")}
            </body>
          </html>
        HTML
      end
    end
  end
end

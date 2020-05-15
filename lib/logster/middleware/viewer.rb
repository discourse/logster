# frozen_string_literal: true

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
              return method_not_allowed("DELETE")
            end

            key = $1
            message = Logster.store.get(key)
            unless message
              return [404, {}, ["Message not found"]]
            end

            Logster.store.delete(message)
            [301, { "Location" => "#{@logs_path}/" }, []]

          elsif resource =~ /\/(un)?protect\/([0-9a-f]+)$/
            off = $1 == "un"
            key = $2

            message = Logster.store.get(key)
            unless message
              return [404, {}, ["Message not found"]]
            end

            if off
              if Logster.store.unprotect(key)
                [301, { "Location" => "#{@logs_path}/show/#{key}?protected=false" }, []]
              else
                [500, {}, ["Failed"]]
              end
            else
              if Logster.store.protect(key)
                [301, { "Location" => "#{@logs_path}/show/#{key}?protected=true" }, []]
              else
                [500, {}, ["Failed"]]
              end
            end

          elsif resource =~ /\/solve\/([0-9a-f]+)$/
            key = $1

            message = Logster.store.get(key)
            unless message
              return [404, {}, ["Message not found"]]
            end

            Logster.store.solve(key)

            [301, { "Location" => "#{@logs_path}" }, []]

          elsif resource =~ /\/clear$/
            if env[REQUEST_METHOD] != "POST"
              return method_not_allowed("POST")
            end
            Logster.store.clear
            [200, {}, ["Messages cleared"]]

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
              preload = { "/show/#{key}" => message }
              [200, { "Content-Type" => "text/html; charset=utf-8" }, [body(preload)]]
            end

          elsif resource =~ /\/settings(\.json)?$/
            json = $1 == ".json"
            if json
              ignore_count = Logster.store.get_all_ignore_count
              suppression = []

              Logster.store.ignore&.each do |pattern|
                string_pattern = Regexp === pattern ? pattern.inspect : pattern.to_s
                count = ignore_count[string_pattern] || 0
                suppression << { value: string_pattern, count: count, hard: true }
              end

              Logster::SuppressionPattern.find_all(raw: true).each do |pattern|
                count = ignore_count[pattern] || 0
                suppression << { value: pattern, count: count }
              end

              grouping = Logster::GroupingPattern.find_all(raw: true).map do |pattern|
                { value: pattern }
              end
              [200, { "Content-Type" => "application/json; charset=utf-8" }, [JSON.generate(suppression: suppression, grouping: grouping)]]
            else
              [200, { "Content-Type" => "text/html; charset=utf-8" }, [body]]
            end
          elsif resource =~ /\/patterns\/([a-zA-Z0-9_]+)\.json$/
            unless Logster.config.enable_custom_patterns_via_ui
              return not_allowed("Custom patterns via the UI is disabled. You can enable it by committing this line to your app source code:\nLogster.config.enable_custom_patterns_via_ui = true")
            end

            set_name = $1
            req = Rack::Request.new(env)
            return method_not_allowed(%w[POST PUT DELETE]) if req.request_method == "GET"

            update_patterns(set_name, req)
          elsif resource == "/reset-count.json"
            req = Rack::Request.new(env)
            return method_not_allowed("PUT") if req.request_method != "PUT"
            pattern = nil
            if [true, "true"].include?(req.params["hard"])
              pattern = Logster.store.ignore.find do |patt|
                str = Regexp === patt ? patt.inspect : patt.to_s
                str == req.params["pattern"]
              end
            else
              pattern = Logster::SuppressionPattern.find_all(raw: true).find do |patt|
                patt == req.params["pattern"]
              end
            end
            return not_found("Pattern not found") unless pattern
            pattern = Regexp === pattern ? pattern.inspect : pattern.to_s
            Logster.store.remove_ignore_count(pattern)
            [200, {}, ["OK"]]
          elsif resource == "/"
            [200, { "Content-Type" => "text/html; charset=utf-8" }, [body]]
          elsif resource =~ /\/fetch-env\/([0-9a-f]+)\.json$/
            key = $1
            env = Logster.store.get_env(key)
            if env
              [200, { "Content-Type" => "application/json; charset=utf-8" }, [JSON.generate(env)]]
            else
              not_found
            end
          elsif resource == '/solve-group'
            return not_allowed unless Logster.config.enable_custom_patterns_via_ui
            req = Rack::Request.new(env)
            return method_not_allowed("POST") if req.request_method != "POST"
            group = Logster.store.find_pattern_groups do |patt|
              patt.inspect == req.params["regex"]
            end.first
            return not_found("No such pattern group exists") if !group
            group.messages_keys.each { |k| Logster.store.solve(k) }
            [200, {}, []]
          elsif resource == '/development-preload.json' && ENV["LOGSTER_ENV"] == "development"
            [200, { "Content-Type" => "application/json; charset=utf-8" }, [JSON.generate(preloaded_data)]]
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
        search = opts[:search]
        if params["known_groups"]
          opts[:known_groups] = params["known_groups"]
        end
        opts[:with_env] = (String === search && search.size > 0) || Regexp === search

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
          args = {}
          if Logster::SuppressionPattern === record && [true, "true"].include?(req.params["retroactive"])
            args[:retroactive] = true
          end
          record.save(args)
        when "PUT"
          record.modify(req.params["new_pattern"])
        when "DELETE"
          record.destroy
        else
          return method_not_allowed(%w[POST PUT DELETE])
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
        when "grouping"
          Logster::GroupingPattern
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

      def method_not_allowed(allowed_methods)
        if Array === allowed_methods
          allowed_methods = allowed_methods.join(", ")
        end
        [405, { "Allow" => allowed_methods }, []]
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

      def preload_backtrace_data
        gems_data = []
        Gem::Specification.find_all do |gem|
          url = gem.metadata["source_code_uri"] || gem.homepage
          if url && url.match(/^https?:\/\/github.com\//)
            gems_data << { name: gem.name, url: url }
          end
        end
        {
          gems_data: gems_data,
          directories: Logster.config.project_directories
        }
      end

      def preloaded_data
        preload = {
          env_expandable_keys: Logster.config.env_expandable_keys,
          patterns_enabled: Logster.config.enable_custom_patterns_via_ui,
          application_version: Logster.config.application_version
        }
        backtrace_links_enabled = Logster.config.enable_backtrace_links
        gems_dir = Logster.config.gems_dir
        gems_dir += "/" if gems_dir[-1] != "/"
        preload.merge!(gems_dir: gems_dir, backtrace_links_enabled: backtrace_links_enabled)

        if backtrace_links_enabled
          preload.merge!(preload_backtrace_data)
        end
        preload
      end

      def body(preload = {})
        preload = preloaded_data.merge(preload)
        root_url = @logs_path
        root_url += "/" if root_url[-1] != "/"
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
              <meta name="client-app/config/environment" content="%7B%22modulePrefix%22%3A%22client-app%22%2C%22environment%22%3A%22production%22%2C%22rootURL%22%3A%22#{root_url}%22%2C%22locationType%22%3A%22history%22%2C%22EmberENV%22%3A%7B%22FEATURES%22%3A%7B%7D%2C%22EXTEND_PROTOTYPES%22%3A%7B%22Date%22%3Afalse%7D%2C%22_APPLICATION_TEMPLATE_WRAPPER%22%3Afalse%2C%22_DEFAULT_ASYNC_OBSERVERS%22%3Atrue%2C%22_JQUERY_INTEGRATION%22%3Afalse%2C%22_TEMPLATE_ONLY_GLIMMER_COMPONENTS%22%3Atrue%7D%2C%22APP%22%3A%7B%22name%22%3A%22client-app%22%2C%22version%22%3A%220.0.0%2B7a424002%22%7D%2C%22exportApplicationGlobal%22%3Afalse%7D" />
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

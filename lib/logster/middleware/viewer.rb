# frozen_string_literal: true

require "json"

module Logster
  module Middleware
    class Viewer
      PATH_INFO = "PATH_INFO".freeze
      SCRIPT_NAME = "SCRIPT_NAME".freeze
      REQUEST_METHOD = "REQUEST_METHOD".freeze
      LOGSTER_RESPONSE = "logster.response".freeze
      COMMON_SECURITY_HEADERS = {
        "cache-control" => "no-store",
        "referrer-policy" => "no-referrer",
        "x-content-type-options" => "nosniff",
        "x-frame-options" => "DENY",
      }.freeze
      MUTATING_ROUTES = [
        [%r{\A/message/[0-9a-f]+\z}, %w[DELETE]],
        [%r{\A/protect/[0-9a-f]+\z}, %w[PUT]],
        [%r{\A/unprotect/[0-9a-f]+\z}, %w[DELETE]],
        [%r{\A/solve/[0-9a-f]+\z}, %w[PUT]],
        [%r{\A/clear\z}, %w[POST]],
        [%r{\A/patterns/[a-zA-Z0-9_]+\.json\z}, %w[POST PUT DELETE]],
        [%r{\A/reset-count\.json\z}, %w[PUT]],
        [%r{\A/solve-group\z}, %w[POST]],
      ].freeze

      def initialize(app)
        @app = app

        @logs_path = Logster.config.subdirectory
        @path_regex = Regexp.new("^(#{@logs_path}$)|^(#{@logs_path}(/.*))$")
        (@store = Logster.store) || raise(ArgumentError.new("store"))

        @assets_path = File.expand_path("../../../../assets", __FILE__)
        @fileserver = Rack::Files.new(@assets_path)
      end

      def call(env)
        env.delete(LOGSTER_RESPONSE)
        response = dispatch(env)
        return response unless env.delete(LOGSTER_RESPONSE)

        status, headers, body = response
        [status, COMMON_SECURITY_HEADERS.merge(headers), body]
      end

      def dispatch(env)
        path = env[PATH_INFO]
        script_name = env[SCRIPT_NAME]

        path = script_name + path if script_name && script_name.length > 0

        if resource = resolve_path(path)
          env[LOGSTER_RESPONSE] = true

          if (authorize_request = Logster.config.authorize_request) && !authorize_request.call(env)
            return not_allowed("Not authorized")
          end

          if allowed_methods = allowed_methods_for(resource)
            if !allowed_methods.include?(env[REQUEST_METHOD])
              return method_not_allowed(allowed_methods)
            end
            return not_allowed("CSRF validation failed") unless valid_csrf_request?(env)
          end

          if resource =~
               /\.ico$|\.js$|\.png|\.handlebars$|\.css$|\.woff$|\.ttf$|\.woff2$|\.svg$|\.otf$|\.eot$/
            serve_file(env, resource)
          elsif resource.start_with?("/messages.json") && env[REQUEST_METHOD] == "POST"
            serve_messages(Rack::Request.new(env))
          elsif resource =~ %r{/message/([0-9a-f]+)$}
            return method_not_allowed("DELETE") if env[REQUEST_METHOD] != "DELETE"

            key = $1
            message = Logster.store.get(key)
            return 404, {}, ["Message not found"] unless message

            Logster.store.delete(message)
            [303, { "location" => "#{@logs_path}/" }, []]
          elsif resource =~ %r{/(un)?protect/([0-9a-f]+)$}
            off = $1 == "un"
            key = $2

            message = Logster.store.get(key)
            return 404, {}, ["Message not found"] unless message

            if off
              if Logster.store.unprotect(key)
                [303, { "location" => "#{@logs_path}/show/#{key}?protected=false" }, []]
              else
                [500, {}, ["Failed"]]
              end
            else
              if Logster.store.protect(key)
                [303, { "location" => "#{@logs_path}/show/#{key}?protected=true" }, []]
              else
                [500, {}, ["Failed"]]
              end
            end
          elsif resource =~ %r{/solve/([0-9a-f]+)$}
            key = $1

            message = Logster.store.get(key)
            return 404, {}, ["Message not found"] unless message

            Logster.store.solve(key)

            [303, { "location" => "#{@logs_path}" }, []]
          elsif resource =~ %r{/clear$}
            return method_not_allowed("POST") if env[REQUEST_METHOD] != "POST"
            Logster.store.clear
            [200, {}, ["Messages cleared"]]
          elsif resource =~ %r{/show/([0-9a-f]+)(\.json)?$}
            key = $1
            json = $2 == ".json"

            message = Logster.store.get(key)
            return 404, {}, ["Message not found"] unless message

            if json
              [200, { "content-type" => "application/json; charset=utf-8" }, [message.to_json]]
            else
              preload = { "/show/#{key}" => message }
              js_app(preload)
            end
          elsif resource =~ %r{/settings(\.json)?$}
            json = $1 == ".json"
            if json
              ignore_count = Logster.store.get_all_ignore_count
              suppression = []

              Logster.store.ignore&.each do |pattern|
                string_pattern = Regexp === pattern ? pattern.inspect : pattern.to_s
                count = ignore_count[string_pattern] || 0
                suppression << { value: string_pattern, count: count, hard: true }
              end

              Logster::SuppressionPattern
                .find_all(raw: true)
                .each do |pattern|
                  count = ignore_count[pattern] || 0
                  suppression << { value: pattern, count: count }
                end

              grouping =
                Logster::GroupingPattern.find_all(raw: true).map { |pattern| { value: pattern } }
              [
                200,
                { "content-type" => "application/json; charset=utf-8" },
                [JSON.generate(suppression: suppression, grouping: grouping)],
              ]
            else
              js_app
            end
          elsif resource =~ %r{/patterns/([a-zA-Z0-9_]+)\.json$}
            unless Logster.config.enable_custom_patterns_via_ui
              return(
                not_allowed(
                  "Custom patterns via the UI is disabled. You can enable it by committing this line to your app source code:\nLogster.config.enable_custom_patterns_via_ui = true",
                )
              )
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
              pattern =
                Logster.store.ignore.find do |patt|
                  str = Regexp === patt ? patt.inspect : patt.to_s
                  str == req.params["pattern"]
                end
            else
              pattern =
                Logster::SuppressionPattern
                  .find_all(raw: true)
                  .find { |patt| patt == req.params["pattern"] }
            end
            return not_found("Pattern not found") unless pattern
            pattern = Regexp === pattern ? pattern.inspect : pattern.to_s
            Logster.store.remove_ignore_count(pattern)
            [200, {}, ["OK"]]
          elsif resource == "/"
            js_app
          elsif resource =~ %r{/fetch-env/([0-9a-f]+)\.json$}
            key = $1
            env = Logster.store.get_env(key)
            if env
              [200, { "content-type" => "application/json; charset=utf-8" }, [JSON.generate(env)]]
            else
              not_found
            end
          elsif resource == "/solve-group"
            return not_allowed unless Logster.config.enable_custom_patterns_via_ui
            req = Rack::Request.new(env)
            return method_not_allowed("POST") if req.request_method != "POST"
            group =
              Logster.store.find_pattern_groups { |patt| patt.inspect == req.params["regex"] }.first
            return not_found("No such pattern group exists") if !group
            group.messages_keys.each { |k| Logster.store.solve(k) }
            [200, {}, []]
          elsif resource == "/development-preload.json" && ENV["LOGSTER_ENV"] == "development"
            [
              200,
              { "content-type" => "application/json; charset=utf-8" },
              [JSON.generate(preloaded_data)],
            ]
          else
            not_found
          end
        else
          @app.call(env)
        end
      end

      protected

      def allowed_methods_for(resource)
        route = MUTATING_ROUTES.find { |pattern, _| pattern.match?(resource) }
        route&.last
      end

      def valid_csrf_request?(env)
        return false unless env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"

        fetch_site = env["HTTP_SEC_FETCH_SITE"]
        return false if fetch_site && !%w[same-origin same-site none].include?(fetch_site)

        origin = env["HTTP_ORIGIN"]
        !origin || origin == Rack::Request.new(env).base_url
      end

      def serve_file(env, path)
        env[PATH_INFO] = path
        # accl redirect is going to be trouble, ensure its bypassed
        env["sendfile.type"] = ""
        @fileserver.call(env)
      end

      def serve_messages(req)
        params = req.params

        opts = { before: params["before"], after: params["after"] }

        if (filter = params["filter"])
          filter = filter.split("_").map { |s| s.to_i }
          opts[:severity] = filter
        end

        if search = params["search"]
          search = (parse_regex(search) || search) if params["regex_search"] == "true"
          opts[:search] = search
        end
        search = opts[:search]
        opts[:known_groups] = params["known_groups"] if params["known_groups"]
        opts[:with_env] = (String === search && search.size > 0) || Regexp === search

        payload = {
          messages: @store.latest(opts),
          total: @store.count,
          search: params["search"] || "",
          filter: filter || "",
        }

        json = JSON.generate(payload)
        [200, { "content-type" => "application/json" }, [json]]
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
          if Logster::SuppressionPattern === record &&
               [true, "true"].include?(req.params["retroactive"])
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

        [200, { "content-type" => "application/json" }, [JSON.generate(pattern: record.to_s)]]
      rescue => err
        error_message = err.message

        unless Logster::Pattern::PatternError === err # likely a bug, give us the backtrace
          error_message += "\n\n#{err.backtrace.join("\n")}"
          return 500, {}, [error_message]
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
        allowed_methods = allowed_methods.join(", ") if Array === allowed_methods
        [405, { "allow" => allowed_methods }, []]
      end

      def parse_regex(string)
        if string =~ %r{/(.+)/(.*)}
          s = $1
          flags = Regexp::IGNORECASE if $2 && $2.include?("i")
          begin
            Regexp.new(s, flags)
          rescue StandardError
            nil
          end
        end
      end

      def resolve_path(path)
        $3 || "/" if path =~ @path_regex
      end

      def css(name, csp_nonce)
        "<link rel='stylesheet' type='text/css' href='#{@logs_path}/stylesheets/#{name}' nonce='#{csp_nonce}'>"
      end

      def script(name, csp_nonce)
        "<script src='#{@logs_path}/javascript/#{name}' nonce='#{csp_nonce}'></script>"
      end

      def to_json_and_escape(payload)
        Rack::Utils.escape_html(JSON.generate(payload))
      end

      def preload_backtrace_data
        gems_data = []
        Gem::Specification.find_all do |gem|
          url = gem.metadata["source_code_uri"] || gem.homepage
          gems_data << { name: gem.name, url: url } if url && url.match(%r{^https?://github.com/})
        end
        { gems_data: gems_data, directories: Logster.config.project_directories }
      end

      def preloaded_data
        preload = {
          env_expandable_keys: Logster.config.env_expandable_keys,
          patterns_enabled: Logster.config.enable_custom_patterns_via_ui,
          application_version: Logster.config.application_version,
        }
        backtrace_links_enabled = Logster.config.enable_backtrace_links
        gems_dir = Logster.config.gems_dir
        gems_dir += "/" if gems_dir[-1] != "/"
        preload.merge!(gems_dir: gems_dir, backtrace_links_enabled: backtrace_links_enabled)

        preload.merge!(preload_backtrace_data) if backtrace_links_enabled
        if Logster.config.back_to_site_link_text && Logster.config.back_to_site_link_path
          preload.merge!(
            back_to_site_link_text: Logster.config.back_to_site_link_text,
            back_to_site_link_path: Logster.config.back_to_site_link_path,
          )
        end
        preload
      end

      def js_app(preload = {})
        csp_nonce = SecureRandom.hex
        preload = preloaded_data.merge(preload)
        root_url = @logs_path
        root_url += "/" if root_url[-1] != "/"
        body = <<~HTML
          <!doctype html>
          <html>
            <head>
              <link rel="shortcut icon" href="#{@logs_path}/images/icon_64x64.png">
              <link rel="apple-touch-icon" href="#{@logs_path}/images/icon_144x144.png" />
              <title>#{Logster.config.web_title || "Logs"}</title>
              <meta name="viewport" content="width=device-width, minimum-scale=1.0, maximum-scale=1.0, user-scalable=yes">
              <meta name="color-scheme" content="dark light">
              #{css("vendor.css", csp_nonce)}
              #{css("client-app.css", csp_nonce)}
              #{script("vendor.js", csp_nonce)}
              <meta id="preloaded-data" data-root-path="#{@logs_path}" data-preloaded="#{to_json_and_escape(preload)}">
              <meta name="client-app/config/environment" content="%7B%22modulePrefix%22%3A%22client-app%22%2C%22environment%22%3A%22production%22%2C%22rootURL%22%3A%22#{root_url}%22%2C%22locationType%22%3A%22history%22%2C%22EmberENV%22%3A%7B%22FEATURES%22%3A%7B%7D%2C%22EXTEND_PROTOTYPES%22%3A%7B%22Date%22%3Afalse%7D%2C%22_APPLICATION_TEMPLATE_WRAPPER%22%3Afalse%2C%22_DEFAULT_ASYNC_OBSERVERS%22%3Atrue%2C%22_JQUERY_INTEGRATION%22%3Afalse%2C%22_TEMPLATE_ONLY_GLIMMER_COMPONENTS%22%3Atrue%7D%2C%22APP%22%3A%7B%22name%22%3A%22client-app%22%2C%22version%22%3A%220.0.0%2B7a424002%22%7D%2C%22exportApplicationGlobal%22%3Afalse%7D" />
            </head>
            <body>
              #{script("client-app.js", csp_nonce)}
            </body>
          </html>
        HTML

        [
          200,
          {
            "content-type" => "text/html; charset=utf-8",
            "content-security-policy" =>
              "default-src 'none'; script-src 'nonce-#{csp_nonce}'; style-src 'self' 'nonce-#{csp_nonce}'; font-src 'self'; img-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self';",
          },
          [body],
        ]
      end
    end
  end
end

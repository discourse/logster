![logster logo](https://raw.githubusercontent.com/discourse/logster/master/website/images/logo-logster-cropped-small.png)

Logster is an embedded Ruby "exception reporting service" admins can view on live websites, at `http://example.com/logs`

## Interface

![Screenshot](https://raw.githubusercontent.com/discourse/logster/master/website/images/logster-screenshot.png)

Play with a live demo at [logster.info/logs](http://logster.info/logs).

## Installation

Add these lines to your application's Gemfile:

    gem 'redis'
    gem 'logster'

And then execute:

    $ bundle

To make logster web available add the following to your `routes.rb`:

```
constraints lambda { |req| req.session["admin"] } do
  mount Logster::Web => "/logs"
end
```

By default, logster will only run in development and production environments.

To run logster in other environments, in `config/application.rb`

```
Logster.set_environments([:development, :staging, :production])
```

### Configuration

Logster can be configured using `Logster.config`:

- `Logster.config.application_version`: set to a unique identifier denoting version of your app. The "solve" function takes this version into account when suppressing errors.
- `Logster.config.enable_js_error_reporting` : enable js error reporting from clients
- `Logster.config.rate_limit_error_reporting` : controls automatic 1 minute rate limiting for JS error reporting.
- `Logster.config.web_title` : `<title>` tag for logster error page.

- `Logster.config.enable_custom_patterns_via_ui` : enable the settings page (`/settings`) where you can add suppression and grouping patterns.

- `Logster.config.allow_grouping` : Enable grouping of similar messages into one messages with an array of `env` of the grouped messages. Similar messages are messages that have identical backtraces, severity and log message.

- `Logster.config.maximum_message_length` : set a maximum length for log messages that are shown inside the `info` tab and in the message rows in the UI. Messages that exceed the specified length will be truncated and an ellipsis will be appended to indicate that the message has been truncated. Default value is 2000.

- `Logster.config.maximum_message_size_bytes` : set a maximum size for message objects. Default value is 10,000. If a message size exceeds this limit, Logster will first remove all occurrences of `gems_dir` (more on this config below) from the backtrace and computes the size again; if the message is still above the limit, Logster will remove as many as character as needed from the backtrace to bring the size below the limit. It's discouraged to set this config to a really low value (e.g. less than 2000) because a message needs a minimum amount of data in order to make sense (the minimum amount varies per message), so the closer the limit is to the minimum amount of space needed, the more of the backtrace will be removed. Keep this in mind when tweaking this config.

- `Logster.config.max_env_bytes` : set a maximum size for `env`. Default value is 1000. In case `env` is an array of hashes, this limit applies to the individual hashes in the array rather than the whole array. If an `env` hash exceeds this limit, Logster will take the biggest subset of key-value pairs whose size is below the limit. If the hash has a key with the name `time`, it will always be included.

- `Logster.config.max_env_count_per_message` : default value is 50. Logster can merge messages that have the same backtrace, severity and log message into one grouping message that have many `env` hashes. This config specifies the maximum number of `env` hashes a grouping message is allowed to keep. If this limit is reached and a new similar message is created and it needs to be merged, Logster will remove the oldest `env` hash from the grouping message and adds the new one.

- `Logster.config.project_directories` : This should be an array of hashes that map paths on the local filesystem to GitHub repository URLs. If this feature is enabled, Logster will parse backtraces and try to construct a GitHub URL to the exact file and line number for each line in the backtrace. For a Rails app, the config may look like this: `Logster.config.project_directories = [{ path: Rails.root.to_s, url: "https://github.com/<your_org>/<your_repo>" }]`. The GitHub links that are constructed will use the `master` branch. If you want Logster to use the `application_version` attribute from the `env` tab so that the GitHub links point to the exact version of the app when the log message is created, add `main_app: true` key to the hash.

- `Logster.config.enable_backtrace_links` : Enable/disable the backtrace links feature.

- `Logster.config.gems_dir` : The value of this config is `Gem.dir + "/gems/"` by default. You probably don't need to change this config, but it's available in case your app gems are installed in a different directory. An example where this config is needed is Logster [demo site](http://logster.info/logs/): [https://github.com/discourse/logster/blob/master/website/sample.rb#L77](https://github.com/discourse/logster/blob/master/website/sample.rb#L77).

### Tracking Error Rate
Logster allows you to register a callback when the rate of errors has exceeded
a given limit.

Tracking buckets available are one minute and an hour.

Example:
```
Logster.register_rate_limit_per_minute(Logger::WARN, 60) do |rate|
  puts "O no! The error rate is now #{rate} errors/min"
end

Logster.register_rate_limit_per_hour([Logger::WARN, Logger::ERROR, Logger::FATAL], 60) do |rate|
  puts "O no! The error rate is now #{rate} errors/hour"
end
```

### Note
If you are seeing the error `No such middleware to insert before: ActionDispatch::DebugExceptions` after installing logster,
then you are using a conflicting gem like `better_errors` or `web-console`.

To avoid this error, make sure logster is added behind those conflicting gems in your Gemfile.

If you're using Logster with a non-rails app, you'll need to be careful that the env hashes of messages that Logster receives don't contain strings with invalid encoding because at some point Logster calls `#to_json` on the message env and the method will fail with `JSON::GeneratorError`.

The reason this doesn't happen in rails apps is because ActiveSupport has a monkey patch for [`#to_json`](https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/object/json.rb).

### Mount using warden (devise)
```
  admin_constraint = lambda do |request|
    request.env['warden'].authenticate? and request.env['warden'].user.admin?
  end

  constraints admin_constraint do
    mount Logster::Web, at: "/logs"
  end
```

### Mount using devise (method 2)
Change :admin_user symbol with your devise user, example :user.
In -> lambda block change admin? method with your authorization method
Or simply define a admin? method in you user model.
```
  authenticate :admin_user, ->(u) { u.admin? } do
    mount Logster::Web, at: "/logs"
  end
```

Out of the box, logster will use the default redis connection, to customise, in `config/application.rb`

```
Logster.store = Logster::RedisStore.new(redis_connection)
```

### Heroku Deployment
In case you may be using the `rails_12factor` gem in a production deployment on Heroku, the standard `Rails.logger` will not cooperate properly with Logster. Extend Rails.logger in your `config/application.rb` or `config/initializers/logster.rb` with:
```
if Rails.env.production?
    Rails.logger.extend(ActiveSupport::Logger.broadcast(Logster.logger))
end
```

## Thanks

Logster UI is built using [Ember.js](http://emberjs.com/)

## Contributing

1. Fork it ( https://github.com/discourse/logster/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Run `cd client-app && npm install`
4. Run `bundle exec rake client_dev` to start Sinatra server (port 9292) and Ember server (port 4200). Use Ember server for hot reload for client code.
5. Once you're done making changes, run `./build_client_app.sh` to make and copy a production build to the assets folder.
6. Commit your changes (`git commit -am 'Add some feature'`)
7. Push to the branch (`git push origin my-new-feature`)
8. Create a new Pull Request

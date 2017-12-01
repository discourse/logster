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

Make logster web available add the following to your `routes.rb`:

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

### Mount using warden (devise)
```
  admin_constraint = lambda do |request|
    request.env['warden'].authenticate? and request.env['warden'].user.admin?
  end

  constraints admin_constraint do
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
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

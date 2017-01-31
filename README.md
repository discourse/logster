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

# CHANGELOG

- 2017-01-30: Version 1.2.7
  - Feature: Add override_level to Logster::Logger allowing for threadsafe logger override

- 2016-10-24: Version 1.2.6
  - Fix: Check if `Rails.env` is defined when using Logster in a none Rails project.

- 2016-07-11: Version 1.2.5
  - Fix: Chained `Logster::Logger` logger now receives backtrace as well.

- 2016-05-05: Version 1.2.4
  - Fix: XSS in log message show if attacker can inject script into ENV

- 2016-05-05: Version 1.2.3
  - Fix: clear_all now also clears rate limits
  - Fix: protect against corrupt data in redis during clear

- 2016-03-22: Version 1.2.2
  - Fix: Conflicting attributes and method name for `Logster::RedisStore#rate_limits`.
  - Fix: Rate limit checker was tracking limits too early. It should only track when a message has been bumped or saved.

- 2016-03-22: Version 1.2.1
  - Feature: Add method to retrieve current rate from rate limiters.
  - Feature: Make `RedisStore#rate_limits` readable.
  - Feature: Make `RedisRateLimiter#callback` and `RedisRateLimiter#duration` readable.

- 2016-03-18: Version 1.2.0
  - Fix: Move Redis configuration into RedisStore.
  - Feature: Allow `RedisStore#redis_prefix` to either be a String or a Proc.

- 2016-02-11: Version 1.1.1
  - Feature: Error rate can now be tracked in one minute and one hour buckets.

- 2015-11-27: Version 1.0.1
  - New assets and logster logo
  - Added favicon
  - Added title
  - Use rails logger instead of invoking store

- 2015-08-18: Version 0.9.9
  - This marks the largest release of Logster to date, it has been in production use for quite a while, hence the version bump.
  - Feature: automatically group errors in production mode, can be manually controlled via Logster.config.allow_grouping
  - Feature: automatically track application version, can be manually controlled via Logster.config.application_version
  - Feature: Font Awesome icons used throughout
  - Feature: Ember upgrade to 1.13
  - Feature: you can now "solve" a class of errors, if error has an application_version and backtrace. Once an error is solved it will no longer be reported for the "solved" application_versions
  - Feature: allow users to delete a single error
  - UX: use table for env
  - Feature: display "protected" state of message in list
  - Feature: use local times as opposed to relative times in time column
  - UX: use Google Roboto font as opposed to system fonts
  - UX: remove pointless titles from log table
  - Feature: If Logster is in a background tab only poll once every 60 seconds (as opposed to 3)
  - Fix: protect/unprotect redirected to show page

- 2015-06-16: Version 0.8.3
  - Chained loggers now respect chain ignore
  - Add hostname and process_id to env on all messages

- 2015-06-10: Version 0.8.2
  - Add hostname and process_id to env on all messages

- 2015-05-01: Version 0.8.1
  - Don't crash out logging routine if redis is down or stderr is closed

- 2015-04-16: Version 0.8.0
  - Improve formatting of /show page
  - Big version bump cause it is quite stable

- 2015-02-27: Version 0.1.7
  - Fix invalid request on ?test

- 2014-08-05: Version 0.1.3
  - Automatically include ignore filter

- 2014-08-13: Version 0.1.6
  - Simplify install process
  - Fix crash on 404 in /logs dir

- 2014-08-10: Version 0.1.5
  - Fix crash in Rails 3

- 2014-08-08: Version 0.1.4
  - Fix crash in ignore filter

- 2014-07-17: Version 0.1.1
  - Refactored report method into base_store.rb - will be easier to make a new log store
  - Add link in UI to clear all (non-protected) logs
  - Add example of submitting logs from Sidekiq jobs
  - Show Protect/Share links on all tabs
  - Render hashes provided via Logster.add_to_env

- 2014-07-04: Version 0.0.12
  - Feature: Able to share logs, at /logs/show/(hexdigits)
  - Add protecting logs, so they aren't deleted when old (for use with sharing)
  - Restructured Redis data model

- 2014-05-24: Version 0.0.10
  - Correct context for error reporting
  - Clean up backtraces of reported exceptions

- 2014-05-13: Version 0.0.9
  - Stray debugger message removed, add window.location logging to js

- 2014-05-13: Version 0.0.8
  - Fix pacakging binstubs by mistake

- 2014-05-13: Version 0.0.7
  - Add support for javascript exception logging

- 2014-05-12: Version 0.0.6
  - Add referer to env

- 2014-05-12: Version 0.0.5
  - Feature: We now log basic rack environment with the messages
  - Add your own with Logster.add_to_env(env, key, value)

- 2014-05-07: Version 0.0.4
  - Feature: Ability to ignore patterns with Logster.store.ignore = [/regex/]
  - Feature: Store backtraces, allow people to view them in the GUI

- 2014-05-07: Started changelog :)
  - Report params in env tab

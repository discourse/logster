# Logster

A web log viewer and logging framework for Rack applications

![logster logo](https://raw.githubusercontent.com/discourse/logster/master/assets/images/logster-logo.png)

## [Live Demo](http://logster.info/logs)

![logster](http://i.imgur.com/cvfcQpv.png)

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

### Note
If you are seeing error
'No such middleware to insert before: ActionDispatch::DebugExceptions' after installing logster,
then you are using a conflicting gem like better_errors.

To avoid this error, make sure logster is added behind those conflicting gems in your Gemfile.

### mount using warden (devise)
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

## Usage

The concept is to have an embedded "exception reporting service" admins can view on live sites.

Logs will be visible by default at `http://sitename.com/logs`


## Thanks

Logster UI is built using [Ember.js](http://emberjs.com/)

## Contributing

1. Fork it ( https://github.com/discourse/logster/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

# CHANGELOG

- 2014-05-07: Started changelog :)
- 2014-05-07: Version 0.0.4
  - Feature: Ability to ignore patterns with Logster.store.ignore = [/regex/]
  - Feature: Store backtraces, allow people to view them in the GUI
- 2014-05-12: Version 0.0.5
  - Feature: We now log basic rack environment with the messages
  - Add your own with Logster.add_to_env(env, key, value)
- 2014-05-12: Version 0.0.6
  - Add referer to env
- 2014-05-13: Version 0.0.7
  - Add support for javascript exception logging
- 2014-05-13: Version 0.0.8
  - Fix pacakging binstubs by mistake
- 2014-05-13: Version 0.0.9
  - Stray debugger message removed, add window.location logging to js
- 2014-05-24: Version 0.0.10
  - Correct context for error reporting
  - Clean up backtraces of reported exceptions
  - Report params in env tab
- 2014-07-04: Version 0.0.12
  - Feature: Able to share logs, at /logs/show/(hexdigits)
  - Add protecting logs, so they aren't deleted when old (for use with sharing)
  - Restructured Redis data model
- 2014-07-17: Version 0.1.1
  - Refactored report method into base_store.rb - will be easier to make a new log store
  - Add link in UI to clear all (non-protected) logs
  - Add example of submitting logs from Sidekiq jobs
  - Show Protect/Share links on all tabs
  - Render hashes provided via Logster.add_to_env
- 2014-08-05: Version 0.1.3
  - Automatically include ignore filter
- 2014-08-08: Version 0.1.4
  - Fix crash in ignore filter
- 2014-08-10: Version 0.1.5
  - Fix crash in Rails 3
- 2014-08-13: Version 0.1.6
  - Simplify install process
  - Fix crash on 404 in /logs dir
- 2015-02-27: Version 0.1.7
  - Fix invalid request on ?test
- 2015-04-16: Version 0.8.0
  - Improve formatting of /show page
  - Big version bump cause it is quite stable
- 2015-05-01: Version 0.8.1
  - Don't crash out logging routine if redis is down or stderr is closed
- 2015-06-10: Version 0.8.2
  - Add hostname and process_id to env on all messages
- 2015-06-16: Version 0.8.3
  - Chained loggers now respect chain ignore
  - Add hostname and process_id to env on all messages

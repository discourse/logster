# Logster

A web log viewer and logging framework for Rack applications

## [Live Demo](http://logster.info/logs)

![logster](http://i.imgur.com/cvfcQpv.png)

## Installation

Add these lines to your application's Gemfile:

    gem 'redis'
    gem 'logster'

And then execute:

    $ bundle

Make Logster available in your development environment by adding the following to your routes.rb:

```
if Rails.env == "development"
  mount Logster::Web => "/logs"
end
```

Logster will be available in your Rails app in **development** mode only. To wire up in production you will need to set

```
Logster.config.authorize_callback = lambda{|env| your_own_can_see_logs? }
```

## Usage

The concept is to have an embedded "exception reporting service" admins can view on live sites.

Logs will be visible by default at `http://sitename.com/logs`

## Thanks

Logster UI is built using [Ember.js](http://emberjs.com/)

## Contributing

1. Fork it ( https://github.com/SamSaffron/logster/fork )
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

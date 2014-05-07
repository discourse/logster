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

Logster will wire up `/logs` path in your Rails app in **development** mode only. Production mode is being worked on.

## Usage

Logster is in current development, at the moment the focus is on a decent tool for dev. Once that is complete production mode will be built.

The concept is to have an embedded "exception reporting service" admins can view on live sites.

Logs will be visible by default at `http://sitename.com/logs`, only dev mode is implemented now. 

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

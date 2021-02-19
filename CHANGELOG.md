# CHANGELOG

- 2021-02-19: 2.9.6

  - UX: Make `Warn` level visible by default

- 2021-01-21: 2.9.5

  - FIX: Stop encoding errors when converting Message objects to JSON (#128)
  - DEV: Bump dependencies

- 2020-09-01: 2.9.4

  - FEATURE: Merge messages differing only by numbers (#118)
  - DEV: Bump dependencies
  - UX: Turn severities below `Error` off by default and remember changes using localStorage (#125)

- 2020-08-20: 2.9.3

  - FIX: fix code that causes warning from recent redis gem

- 2020-08-11: 2.9.2

  - FIX: `report_js_error` incorrectly denying logs when Redis#exists returns integer

- 2020-07-20: 2.9.1

  - FIX: Missing application backtrace in chained loggers.

- 2020-06-11: 2.9.0

  - FEATURE: Allows JS errors to specify a log severity
  - DEV: Several dependencies upgrades
  - FIX: Don't search if the phrase hasn't changed
  - UX: Distinguish the value of the current env from the values of other envs in a merged message

- 2020-03-30: 2.8.0

  - FEATURE: Upgrade icons to Font Awesome 5

- 2020-03-03: 2.7.1

  - FIX: Stop env mutation to allow all chained loggers to have the same env (#110)

- 2020-02-26: 2.7.0

  - FEATURE: Make log message max length configurable and bump the default to 2000 (#109)

- 2020-02-17: 2.6.3

  - FIX: Respect redis namespace when fetching env using LUA

- 2020-02-09: 2.6.2

  - FIX: Regression with rendering single env when `env_expandable_keys` config is present
  - DEV: Fix Ember deprecations in tests
  - DEV: Add more tests to env rendering
  - FIX: Backtrace frames from gems should be linkified even when they don't start with `gems_dir`
  - DEV: Allow Ember server to inherit preload data from Sinatra server
  - FIX: Fetch env when navigating through grouped messages

- 2020-02-07: 2.6.1

  - FIX: Fetch env when row is selected to allow copy to work on Firefox

- 2020-02-07: 2.6.0

  - DEV: Bump handlebars from 4.1.2 to 4.5.3 in /client-app (#102)
  - FEATURE: Linkify backtrace lines to github (#104)
  - UX: Keep the 50 most recent envs rather than the first 50 (#103). Also introduces new config options `max_env_bytes` and `max_env_count_per_message`.
  - FEATURE: Solve All button for messages grouped by pattern (#105)
  - FEATURE: Copy button for messages (#106)
  - DEV: Upgrade Ember to 3.15 and remove jQuery and lodash as dependencies (#107)

- 2019-12-13: 2.5.1

  - DEV: Bump puma from 4.2.1 to 4.3.1 in /website (#100)
  - FIX: Don't include messages that were removed from groups due to max size limit
  - FIX: loadingEnv is an attribute of model
  - FIX: Prevent crashing when reporting a non-string message to Logster
  - UX: Group count attribute should be a long-running number of errors, not just the number of errors the group currently contains

- 2019-12-12: 2.5.0

  - DEV: Update to latest version of gems
  - FIX: when rate limiting return an object responding to each
  - FEATURE: Expose the search phrase in query params
  - DEV: Update minor frontend dependencies
  - FEATURE: Custom grouping patterns

- 2019-10-28: 2.4.2

  - FIX: wrong number of arguments when adding message using a block (#98)

- 2019-10-17: 2.4.1

  - PERF: Debounce search field so it doesn't fire a search query at every keystroke.
  - PERF: Disallow search terms that are fewer than 2 characters long.
  - PERF: Bypass refresh cycle if previous cycle hasn't finished.
  - PERF: Defer sending message envs to client until the user requests them.
  - PERF: Cap message size to 60,000 bytes by default.

- 2019-10-10: 2.4.0

  - FEATURE: Allow having retroactive affect when adding suppression patterns
  - DEV: Bump JS dependencies

- 2019-10-08: 2.3.3

  - FEATURE: keep track of message timestamp when it's merged into another message

- 2019-08-20: 2.3.2

  - FEATURE: automatic 1 minute rate limiting for js error reporting per IP

- 2019-08-15: 2.3.1

  - DEV: upgrade Ember to 3.8 and jQuery to 3.4.1 (#84)
  - FIX: properly escape string ignore pattern (#88)
  - FIX: scrub params if they have invalid encoding (#92)

- 2019-03-26: 2.3.0

  - FEATURE: track count of suppressed logs for each pattern

- 2019-03-19: 2.2.0

  - FEATURE: custom suppression patterns via UI
  - UX: auto expand env keys when list length is <= 3

- 2019-03-14: Unreleased

  - FIX: Logster message options missing when base logger is a sub-class of
    `Logster::Logger`

- 2019-02-21: Version 2.1.2

  - FEATURE: allow certain env keys to be expandable via `Logster.config.env_expandable_keys.push(:key, :another_key)`. See https://github.com/discourse/logster/pull/81 for more info

- 2019-02-21: Version 2.1.1

  - FEATURE: allow defer logger to be disabled as Ruby 2.5.3 can segfault with defer logger due to a bug in Ruby. To disable run `Logster::Scheduler.disable`

- 2019-02-13: Version 2.1.0

  - FEATURE/DEV: adds a defer logger that will do logging asynchronously only in dev environments. It should speed things up a little in dev.

- 2019-02-05: Version 2.0.1

  - FIX: env line height issue on iOS

- 2019-01-17: Version 2.0.0.pre

  - FIX: don't merge any new env samples if there are 50 samples (1.4.0.pre regression)
  - UX: make env navigation controls stick to the top when scrolled
  - PERF: store env samples separately from the rest of message data
  - DEV: Rubocop

- 2019-01-09: Version 1.4.0.pre

  - FEATURE: allow navigation through merged errors
  - FEATURE: search should look at env
  - FIX: deselect message if new filtering doesn't include selected message
  - UX: don't give timestamps more space than they need; use `div`s with flexbox instead of `table`
  - FIX: hide "load more" when there are no more messages and filters/search applied

- 2018-12-30: Version 1.3.4

  - FIX: linear-gradient issue on iOS
  - FIX: actions menu should have highest z-index

- 2018-12-26: Version 1.3.3

  - Fix: fix double lines logs when date is too long

- 2018-12-25: Version 1.3.2

  - UX: improve usability on mobile

- 2018-11-09: Version 1.3.1

  - Feature: auto scrub invalid messages reported to logger

- 2018-11-09: Version 1.3.0

  - Feature: upgrade Ember to 3.5.1
  - Feature: remove inline JS for CSP compliance

- 2018-08-13: Version 1.2.10

  - Feature: expose chained loggers in Logster::Logger

- 2017-10-27: Version 1.2.8

  - Fix: `Logster::Middleware::DebugExceptions` is passed a request in Rails 5 instead of the env.

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

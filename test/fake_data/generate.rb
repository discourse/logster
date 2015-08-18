require 'redis'
require 'logster'

Logster.config.allow_grouping = true
Logster.config.application_version = "ABC123"
Logster.store = Logster::RedisStore.new

10.times do
  Logster.store.report(Logger::WARN, "application", "test warning", backtrace: "method1\nmethod2", env: {something: ["hello world", "hello places"], another: {thing: "something else"}})
end

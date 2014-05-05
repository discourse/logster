require 'redis'
require 'logster/redis_store'
require 'logster/message'
require 'json'

store = Logster::RedisStore.new(Redis.new)
latest = store.latest(limit:1000)

json = JSON.generate(latest)

path = File.expand_path('../../data/data.json', __FILE__)
File.open(path, 'w') {|f| f.write(json)}
puts "Wrote #{latest.count} messages into #{path}"

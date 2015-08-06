# Run with 'bundle exec rackup'

require 'redis'
require 'logster'
require 'logster/middleware/reporter'
require 'logster/middleware/viewer'
require 'json'

require 'sinatra'
require 'sinatra/base'

# log a few errors
$redis = Redis.new
$store = Logster.store = Logster::RedisStore.new($redis)
$log = Logster.logger = Logster::Logger.new($store)

class SampleLoader
  def initialize
    @index = 0
    @sample_data_key = 'sample_data'
  end


  def ensure_samples_loaded
    $redis.del @sample_data_key
    data = File.read('data/data.json')
    parsed = JSON.parse(data)
    parsed.each do |row|
      $redis.rpush @sample_data_key, JSON.fast_generate(row)
    end
    @length = parsed.length
  end

  def load_samples
    Thread.new do
      while true
        sleep 5
        begin
          load_next_sample
        rescue => e
          $store.report(4, "logster", e.to_s)
        end
      end
    end
  end

  def load_next_sample
    message =  JSON.parse($redis.lindex(@sample_data_key, @index))
    @index += 1
    @index %= @length

    $store.report(message["severity"], message["progname"], message["message"], {
      backtrace: message["backtrace"],
      env: message["env"]
    })
  end

  def load_error
    # 2 = Severity.WARN
    params = {}
    params["always_present"] = "some_value_#{rand(3)}"
    params["key_#{rand(3)}"] = "some_value_#{rand(3)}"
    $store.report(2, '', "Message message message", {
      backtrace: 'Backtrace backtrace backtrace',
      env: {something: :foo, random: rand(3), array: [1,2,3], rand_array: [10, 11, rand(300)], params: params}
    })
  end
end

$loader = SampleLoader.new
$loader.ensure_samples_loaded
$loader.load_samples
Logster.config.allow_grouping = true

class Sample < Sinatra::Base
  use Logster::Middleware::Viewer
  use Logster::Middleware::Reporter

  get '/' do

<<HTML
<html>
<head>
</head>
<body>
<h3>Welcome to logster:</h3>
<ul>
  <li><a href='https://github.com/SamSaffron/logster'>Learn about logster</a></li>
  <li><a href='/logs'>View sample dev logs</a></li>
</ul>
</body>
</html>
HTML

  end

  get '/report_error' do
    $loader.load_next_sample
    $loader.load_error
  end

end

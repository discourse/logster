# frozen_string_literal: true

# Run with 'bundle exec rackup'

require "redis"
require "logster"
require "logster/middleware/reporter"
require "logster/middleware/viewer"
require "json"
require "sinatra"
require "sinatra/base"

# log a few errors
SAMPLE_REDIS = Redis.new
SAMPLE_STORE = Logster.store = Logster::RedisStore.new(SAMPLE_REDIS)
Logster.logger = Logster::Logger.new(SAMPLE_STORE)

class SampleLoader
  def initialize
    @index = 0
    @sample_data_key = "sample_data"
  end

  def ensure_samples_loaded
    SAMPLE_REDIS.del @sample_data_key
    data = File.read("data/data.json")
    parsed = JSON.parse(data)
    parsed.each { |row| SAMPLE_REDIS.rpush @sample_data_key, JSON.fast_generate(row) }
    @length = parsed.length
  end

  def load_samples
    Thread.new do
      while true
        sleep 5
        begin
          load_next_sample
        rescue => e
          SAMPLE_STORE.report(4, "logster", e.to_s)
        end
      end
    end
  end

  def load_next_sample
    message = JSON.parse(SAMPLE_REDIS.lindex(@sample_data_key, @index))
    @index += 1
    @index %= @length

    SAMPLE_STORE.report(
      message["severity"],
      message["progname"],
      message["message"],
      backtrace: message["backtrace"],
      env: message["env"],
      count: message["count"],
    )
  end

  def load_error
    # 2 = Severity.WARN
    params = {}
    params["always_present"] = "some_value_#{rand(3)}"
    params["key_#{rand(3)}"] = "some_value_#{rand(3)}"
    SAMPLE_STORE.report(
      2,
      "",
      "Message message message",
      backtrace: "Backtrace backtrace backtrace",
      env: {
        something: :foo,
        random: rand(3),
        array: [1, 2, 3],
        rand_array: [10, 11, rand(300)],
        params: params,
      },
    )
  end
end

SampleLoaderInstance = SampleLoader.new
SampleLoaderInstance.ensure_samples_loaded
SampleLoaderInstance.load_samples unless ENV["NO_DATA"]
Logster.config.allow_grouping = true
Logster.config.enable_custom_patterns_via_ui = ENV["LOGSTER_ENABLE_CUSTOM_PATTERNS_VIA_UI"] == "1"
Logster.config.application_version = "b329e23f8511b7248c0e4aee370a9f8a249e1b84"
Logster.config.gems_dir = "/home/sam/.rbenv/versions/2.1.2.discourse/lib/ruby/gems/2.1.0/gems/"
Logster.config.project_directories = [
  {
    path: "/home/sam/Source/discourse",
    url: "https://github.com/discourse/discourse",
    main_app: true,
  },
]

class Sample < Sinatra::Base
  use Logster::Middleware::Viewer
  use Logster::Middleware::Reporter

  get "/" do
    <<HTML
<html>
<head>
</head>
<body>
<h3>Welcome to logster:</h3>
<ul>
  <li><a href='https://github.com/SamSaffron/logster'>Learn about logster</a></li>
  <li><a href='/logs/'>View sample dev logs</a></li>
</ul>
</body>
</html>
HTML
  end

  get "/report_error" do
    SampleLoaderInstance.load_next_sample
    SampleLoaderInstance.load_error
  end
end

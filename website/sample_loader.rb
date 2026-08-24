# frozen_string_literal: true

require "json"
require "logger"

class SampleLoader
  MAX_BATCH_SIZE = 100
  SCENARIOS = {
    "mixed" => "Balanced mix of every shape",
    "exceptions" => "Ruby exceptions with realistic backtraces",
    "requests" => "HTTP failures with nested request context",
    "database" => "SQL errors, binds, and timing metadata",
    "jobs" => "Background job failures and retries",
    "duplicates" => "Repeated events that exercise aggregation",
    "severity" => "Debug through fatal severity coverage",
    "unicode" => "Unicode, multiline, and unusual messages",
  }.freeze
  MIXED_SCENARIOS = (SCENARIOS.keys - ["mixed"]).freeze

  attr_reader :length

  def initialize(store:, redis: nil, data_path: nil)
    @store = store
    @redis = redis
    @data_path = data_path
    @index = 0
    @sample_data_key = "sample_data"
  end

  def ensure_samples_loaded
    raise ArgumentError, "redis and data_path are required" if !@redis || !@data_path

    @redis.del @sample_data_key
    parsed = JSON.parse(File.read(@data_path))
    parsed.each { |row| @redis.rpush @sample_data_key, JSON.generate(row) }
    @length = parsed.length
  end

  def load_samples
    Thread.new do
      loop do
        sleep 5
        load_next_sample
      rescue => error
        @store.report(Logger::ERROR, "logster", error.to_s)
      end
    end
  end

  def load_next_sample
    raise "No sample data loaded" if !@redis || !@length&.positive?

    message = JSON.parse(@redis.lindex(@sample_data_key, @index))
    @index = (@index + 1) % @length

    @store.report(
      message["severity"],
      message["progname"],
      message["message"],
      backtrace: message["backtrace"],
      env: message["env"],
      count: message["count"],
    )
  end

  def report_scenario(scenario:, count:, seed: nil)
    scenario = scenario.to_s
    count = Integer(count)
    raise ArgumentError, "Unknown scenario: #{scenario}" if !SCENARIOS.key?(scenario)
    if !(1..MAX_BATCH_SIZE).cover?(count)
      raise ArgumentError, "Count must be between 1 and #{MAX_BATCH_SIZE}"
    end

    seed = seed.nil? || seed.to_s.empty? ? Random.new_seed : Integer(seed)
    random = Random.new(seed)
    severities = Hash.new(0)

    count.times do |index|
      selected = scenario == "mixed" ? MIXED_SCENARIOS[index % MIXED_SCENARIOS.length] : scenario
      report = build_report(selected, index, random)
      @store.report(report[:severity], report[:progname], report[:message], report[:options])
      severities[severity_name(report[:severity])] += 1
    end

    { scenario: scenario, generated: count, seed: seed, severities: severities }
  end

  private

  def build_report(scenario, index, random)
    send("build_#{scenario}_report", index, random)
  end

  def build_exceptions_report(index, random)
    exception = %w[NoMethodError ArgumentError RuntimeError Timeout::Error][index % 4]
    {
      severity: index % 4 == 3 ? Logger::FATAL : Logger::ERROR,
      progname: "web",
      message: "#{exception}: simulated checkout failure ##{index + 1}",
      options: {
        backtrace: ruby_backtrace("checkout", 40 + index),
        env:
          base_env(random).merge(
            exception_class: exception,
            request_id: request_id(random),
            user: {
              id: random.rand(1..500),
              role: %w[admin moderator member].sample(random: random),
            },
          ),
      },
    }
  end

  def build_requests_report(index, random)
    status = [400, 401, 404, 422, 429, 500, 503][index % 7]
    host = %w[community.local admin.local api.local][index % 3]
    snapshots =
      2.times.map do |attempt|
        base_env(random).merge(
          "HTTP_HOST" => host,
          "REQUEST_METHOD" => %w[GET POST PUT DELETE][(index + attempt) % 4],
          "PATH_INFO" => %w[/topics /admin/users /session /uploads][index % 4],
          :attempt => attempt + 1,
          :params => {
            page: random.rand(1..20),
            filters: %w[open unread assigned],
            token: "[FILTERED]",
          },
        )
      end

    {
      severity: status >= 500 ? Logger::ERROR : Logger::WARN,
      progname: "rack",
      message: "HTTP #{status} while processing request on #{host}",
      options: {
        backtrace: ruby_backtrace("requests", 70 + index),
        env: snapshots,
      },
    }
  end

  def build_database_report(index, random)
    tables = %w[users topics posts notifications]
    table = tables[index % tables.length]
    duration = random.rand(50..2_500)
    {
      severity: duration > 1_500 ? Logger::ERROR : Logger::WARN,
      progname: "database",
      message: "Database query failed after #{duration}ms\nSELECT * FROM #{table} WHERE id = $1",
      options: {
        backtrace: ruby_backtrace("persistence", 100 + index),
        env:
          base_env(random).merge(
            adapter: "postgresql",
            database: "logster_development",
            duration_ms: duration,
            sql: "SELECT * FROM #{table} WHERE id = $1",
            binds: [{ name: "id", value: random.rand(1..10_000) }],
            pool: {
              size: 10,
              busy: random.rand(1..10),
              waiting: random.rand(0..3),
            },
          ),
      },
    }
  end

  def build_jobs_report(index, random)
    jobs = %w[DigestEmailJob ReindexSearchJob SyncWebhookJob CleanupUploadsJob]
    job = jobs[index % jobs.length]
    retry_count = random.rand(0..8)
    {
      severity: retry_count >= 5 ? Logger::ERROR : Logger::WARN,
      progname: "sidekiq",
      message: "#{job} failed on retry #{retry_count}",
      options: {
        backtrace: ruby_backtrace("jobs", 130 + index),
        env:
          base_env(random).merge(
            job: {
              class: job,
              jid: Array.new(12) { random.rand(16).to_s(16) }.join,
              queue: %w[default critical low].sample(random: random),
              retry_count: retry_count,
              arguments: [{ topic_id: random.rand(1..5_000), force: index.even? }],
            },
          ),
      },
    }
  end

  def build_duplicates_report(index, random)
    variant = index % 3
    {
      severity: [Logger::WARN, Logger::ERROR, Logger::ERROR][variant],
      progname: "aggregator",
      message:
        [
          "Repeated cache miss for site settings",
          "Repeated connection reset from upstream",
          "Repeated serializer failure for malformed payload",
        ][
          variant
        ],
      options: {
        backtrace: ruby_backtrace("duplicates_#{variant}", 160 + variant),
        env: base_env(random).merge(occurrence: index + 1, aggregate_variant: variant),
      },
    }
  end

  def build_severity_report(index, random)
    severity = index % 5
    {
      severity: severity,
      progname: "severity-demo",
      message: "#{severity_name(severity).upcase} sample event ##{index + 1}",
      options: {
        backtrace: severity >= Logger::WARN ? ruby_backtrace("severity", 190 + index) : nil,
        env: base_env(random).merge(feature: "severity coverage", sample_index: index),
      },
    }
  end

  def build_unicode_report(index, random)
    messages = [
      "Unicode payload failed: café ☕ — naïve façade",
      "多言語ログ: リクエストを処理できませんでした",
      "Emoji storm 🚨🔥💥 while parsing input",
      "Multiline event\nsecond line\nthird line with\ttab",
    ]
    {
      severity: index.even? ? Logger::WARN : Logger::INFO,
      progname: "encoding",
      message: messages[index % messages.length],
      options: {
        backtrace: ruby_backtrace("encoding", 220 + index),
        env:
          base_env(random).merge(
            encoding: "UTF-8",
            samples: ["café", "日本語", "🚀", nil, true, 42],
            nested: {
              punctuation: "<>&\"'",
              empty: "",
              null: nil,
            },
          ),
      },
    }
  end

  def base_env(random)
    {
      application_version: "b329e23f8511b7248c0e4aee370a9f8a249e1b84",
      environment: "development",
      hostname: %w[web-1 web-2 worker-1].sample(random: random),
      process_id: random.rand(1_000..9_999),
      ruby_version: RUBY_VERSION,
      timestamp: Time.now.to_f,
    }
  end

  def ruby_backtrace(namespace, line)
    [
      "/home/logster/app/services/#{namespace}_service.rb:#{line}:in `call'",
      "/home/logster/app/controllers/sample_controller.rb:18:in `create'",
      "/home/logster/vendor/bundle/ruby/3.4.0/gems/rack-3.0.0/lib/rack/runtime.rb:24:in `call'",
    ].join("\n")
  end

  def request_id(random)
    Array.new(16) { random.rand(16).to_s(16) }.join
  end

  def severity_name(severity)
    %w[debug info warn error fatal][severity] || "unknown"
  end
end

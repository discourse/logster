# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require_relative "frontend_assets"

Rake::TestTask.new do |t|
  t.test_files = FileList["test/**/test_*"].exclude(%r{test/logster/test_railtie\.rb})
end

task(default: :test)

desc "Build the frontend assets required by the gem"
task :build_client_app do
  if ENV["LOGSTER_SKIP_ASSET_BUILD"] == "1"
    begin
      FrontendAssets.verify!(File.expand_path(__dir__))
    rescue FrontendAssets::Error => error
      abort error.message
    end
    puts "Using pre-built frontend assets"
  else
    sh File.expand_path("build_client_app.sh", __dir__)
  end
end

task build: :build_client_app

desc "Starts Sinatra and Ember servers"
task :client_dev do
  begin
    pid = spawn("cd website && LOGSTER_ENV=development BUNDLE_GEMFILE=Gemfile bundle exec puma")
    pid2 = spawn("cd client-app && pnpm start --port 4200")
    Process.wait pid
    Process.wait pid2
  rescue Interrupt => e
    sleep 0.5
    puts "Done!"
    exit 0
  end
end

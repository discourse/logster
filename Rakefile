# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.test_files = FileList["test/**/test_*"].exclude(%r{test/logster/test_railtie\.rb})
end

task(default: :test)

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

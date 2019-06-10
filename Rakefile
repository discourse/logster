require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.pattern = "test/**/test_*.rb"
end

task(default: :test)

desc "Starts Sinatra and Ember servers"
task :client_dev do
  begin
    pid = spawn("cd website && BUNDLE_GEMFILE=Gemfile bundle exec rackup")
    pid2 = spawn("cd client-app && ember s --proxy http://localhost:9292")
    Process.wait pid
    Process.wait pid2
  rescue Interrupt => e
    puts "Done!"
    exit 0
  end
end

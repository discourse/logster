require "bundler/gem_tasks"
require "rake/testtask"

desc "copy js assets"
task :copy_assets do
  `cp bower_components/moment/min/moment.min.js assets/javascript/external`
  `cp bower_components/jquery/dist/jquery.min.js assets/javascript/external`
  `cp bower_components/ember/ember.js assets/javascript/external`
  `cp bower_components/ember/ember.min.js assets/javascript/external`
  `cp bower_components/handlebars/handlebars.min.js assets/javascript/external`
  `cp bower_components/lodash/dist/lodash.min.js assets/javascript/external`
end

Rake::TestTask.new do |t|
  t.pattern = "test/**/test_*.rb"
end

task(default: :test)

require "bundler/gem_tasks"
require "rake/testtask"

desc "copy js assets"
task :copy_assets do
  `rm -fr assets/javascript/external`
  `mkdir assets/javascript/external`
  `cp bower_components/moment/min/moment.min.js assets/javascript/external`
  `cp bower_components/jquery/dist/jquery.min.js assets/javascript/external`
  `cp bower_components/ember/ember-template-compiler.js assets/javascript/external`
  `cp bower_components/ember/ember.js assets/javascript/external`
  `cp bower_components/ember/ember.min.js assets/javascript/external`
  `cp bower_components/lodash/dist/lodash.min.js assets/javascript/external`
  `cp bower_components/components-font-awesome/css/font-awesome.min.css assets/stylesheets`
  `rm -fr assets/fonts`
  `cp -r bower_components/components-font-awesome/fonts assets`
end

Rake::TestTask.new do |t|
  t.pattern = "test/**/test_*.rb"
end

task(default: :test)

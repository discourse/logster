# frozen_string_literal: true

# This script takes care of updating the content of the preloaded json in app/index.html and tests/index.html
# All you need to do is update the ruby hash of the corresponding file you want to update and run the script

require 'bundler/inline'
require 'json'
require 'cgi'

gemfile do
  source 'https://rubygems.org'
  gem 'nokogiri'
end

tests_index_html = {
  env_expandable_keys: [],
  gems_dir: "/var/www/discourse/vendor/bundle/ruby/2.6.0/gems/",
  backtrace_links_enabled: true,
  gems_data: [
    {
      name: "activerecord",
      url: "https://github.com/rails/rails/tree/v6.0.1/activerecord"
    }
  ],
  directories: [
    {
      path: "/var/www/discourse",
      url: "https://github.com/discourse/discourse",
      main_app: true
    },
    {
      path: "/var/www/discourse/plugins/discourse-prometheus",
      url: "https://github.com/discourse/discourse-prometheus"
    }
  ],
  application_version: "ce512452b512b909c38e9c63f2a0e1f8c17a2399"
}

app_index_html = {
  env_expandable_keys: [],
  patterns_enabled: true,
  gems_dir: "/home/sam/.rbenv/versions/2.1.2.discourse/lib/ruby/gems/2.1.0/gems/",
  backtrace_links_enabled: true,
  gems_data: [],
  directories: [
    {
      path: "/home/sam/Source/discourse",
      url: "https://github.com/discourse/discourse",
      main_app: true
    }
  ],
  application_version: "b329e23f8511b7248c0e4aee370a9f8a249e1b84"
}

types = { app: app_index_html, tests: tests_index_html }

%i{app tests}.each do |type|
  content = File.read("#{type}/index.html")
  json = CGI.escapeHTML(JSON.generate(types[type]))
  content.sub!(/data-preloaded=".*">$/, "data-preloaded=\"#{json}\">")
  File.write("#{type}/index.html", content)
end

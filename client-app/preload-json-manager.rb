# frozen_string_literal: true

# This script takes care of updating the content of the preloaded json in tests/index.html
# All you need to do is update the `tests_index_html` hash and run the script

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

content = File.read("tests/index.html")
json = CGI.escapeHTML(JSON.generate(tests_index_html))
content.sub!(/data-preloaded=".*">$/, "data-preloaded=\"#{json}\">")
File.write("tests/index.html", content)

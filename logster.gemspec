# coding: utf-8
# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) if !$LOAD_PATH.include?(lib)
require "logster/version"

Gem::Specification.new do |spec|
  spec.name = "logster"
  spec.version = Logster::VERSION
  spec.authors = ["Sam Saffron"]
  spec.email = ["sam.saffron@gmail.com"]
  spec.summary = "UI for viewing logs in Rack"
  spec.description = "UI for viewing logs in Rack"
  spec.homepage = "https://github.com/discourse/logster"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.3.0"

  runtime_files = %w[CHANGELOG.md LICENSE.txt README.md]
  files =
    `git ls-files -z`.split("\x0")
      .select do |file|
        File.file?(file) &&
          (runtime_files.include?(file) || file.start_with?("lib/", "vendor/", "assets/images/"))
      end
  required_assets = %w[
    assets/manifest.json
    assets/javascript/vendor.js
    assets/javascript/client-app.js
    assets/stylesheets/vendor.css
    assets/stylesheets/client-app.css
  ]
  files += required_assets
  files += Dir.glob("assets/javascript/*")
  files += Dir.glob("assets/stylesheets/*")
  spec.files = files.uniq

  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  # NOTE dependency on rack is not explicit, this enables us to use
  # logster outside of rack (for reporting)

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "redis", "~> 6.0"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-minitest"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "debug"
  spec.add_development_dependency "rubocop-discourse"
  spec.add_development_dependency "syntax_tree"
end

# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'logster/version'

Gem::Specification.new do |spec|
  spec.name          = "logster"
  spec.version       = Logster::VERSION
  spec.authors       = ["UI for viewing logs in Rack"]
  spec.email         = ["sam.saffron@gmail.com"]
  spec.summary       = %q{UI for viewing logs in Rack}
  spec.description   = %q{UI for viewing logs in Rack}
  spec.homepage      = "https://github.com/discourse/logster"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.start_with?("bower_components") || f.start_with?("website") || f.start_with?("bin")
  end
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  # NOTE dependency on rack is not explicit, this enables us to use
  # logster outside of rack (for reporting)

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rack"
  spec.add_development_dependency "redis"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-minitest"
  spec.add_development_dependency "timecop"
end

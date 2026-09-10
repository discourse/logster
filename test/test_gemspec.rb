# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

class TestGemspec < Minitest::Test
  GEMSPEC_PATH = File.expand_path("../logster.gemspec", __dir__)
  PROJECT_ROOT = File.expand_path("..", __dir__)
  REQUIRED_ASSETS = %w[assets/manifest.json assets/logster-config.json].freeze

  def spec_files(directory: PROJECT_ROOT)
    script = <<~'RUBY'
      require "json"
      spec = Gem::Specification.load(ARGV.fetch(0))
      puts "SPEC_FILES=#{JSON.generate(spec.files)}"
    RUBY
    output, status = Open3.capture2e(RbConfig.ruby, "-e", script, GEMSPEC_PATH, chdir: directory)
    assert(status.success?, output)
    JSON.parse(output.lines.grep(/^SPEC_FILES=/).last.delete_prefix("SPEC_FILES="))
  end

  def test_runtime_gem_excludes_development_trees
    files = spec_files

    %w[client-app/ test/ gemfiles/ .github/].each do |prefix|
      refute(files.any? { |file| file.start_with?(prefix) }, "#{prefix} should not ship")
    end
  end

  def test_required_frontend_assets_are_always_declared
    Dir.mktmpdir do |directory|
      files = spec_files(directory:)
      REQUIRED_ASSETS.each { |asset| assert_includes(files, asset) }
    end
  end

  def test_test_bundle_is_not_packaged
    refute(
      spec_files.any? { |file| File.basename(file).start_with?("tests-") },
      "the test bundle should not ship with the gem",
    )
  end
end

# frozen_string_literal: true

require_relative "test_helper"
require_relative "../frontend_assets"
require "fileutils"
require "tmpdir"
require "json"
require "open3"
require "rbconfig"

class TestGemspec < Minitest::Test
  GEMSPEC_PATH = File.expand_path("../logster.gemspec", __dir__)

  # The gemspec reads the working directory, so load it from the project root.
  def self.spec_files
    @spec_files ||=
      begin
        script = <<~'RUBY'
          require "json"
          puts JSON.generate(Gem::Specification.load(ARGV.fetch(0)).files)
        RUBY
        output, status =
          Open3.capture2e(
            RbConfig.ruby,
            "-e",
            script,
            GEMSPEC_PATH,
            chdir: File.dirname(GEMSPEC_PATH),
          )
        raise output unless status.success?
        JSON.parse(output.lines.last)
      end
  end

  def test_runtime_gem_excludes_development_trees
    %w[client-app/ test/ gemfiles/ .github/].each do |prefix|
      refute(
        self.class.spec_files.any? { |file| file.start_with?(prefix) },
        "#{prefix} should not ship",
      )
    end
  end

  # The exclusions above cannot tell a tightened file list from one that drops
  # the frontend altogether, so stage what would ship and check it end to end.
  def test_the_packaged_gem_carries_a_usable_frontend
    root = File.dirname(GEMSPEC_PATH)
    unless File.file?(File.join(root, "assets", "manifest.json"))
      skip("run build_client_app.sh first")
    end

    Dir.mktmpdir do |staged|
      self.class.spec_files.each do |file|
        destination = File.join(staged, file)
        FileUtils.mkdir_p(File.dirname(destination))
        FileUtils.cp(File.join(root, file), destination)
      end

      assert(FrontendAssets.verify!(staged))
      assert_path_exists(File.join(staged, "lib", "logster", "middleware", "viewer.rb"))
      assert_path_exists(File.join(staged, "vendor", "assets", "javascripts", "logster.js.erb"))
      assert_path_exists(File.join(staged, "assets", "images", "icon_64x64.png"))
    end
  end

  def test_test_bundle_is_not_packaged
    refute(
      self.class.spec_files.any? { |file| File.basename(file).start_with?("tests-") },
      "the test bundle should not ship with the gem",
    )
  end
end

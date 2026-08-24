# frozen_string_literal: true

require_relative "test_helper"
require_relative "../frontend_assets"
require "fileutils"
require "json"
require "tmpdir"

class TestFrontendAssets < Minitest::Test
  def with_assets
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p(File.join(directory, "assets", "javascript"))
      FileUtils.mkdir_p(File.join(directory, "assets", "stylesheets"))
      File.write(File.join(directory, "assets", "javascript", "app.js"), "")
      File.write(File.join(directory, "assets", "stylesheets", "app.css"), "")
      File.write(
        File.join(directory, "assets", "manifest.json"),
        JSON.generate("javascript" => ["app.js"], "stylesheets" => ["app.css"], "config" => {}),
      )
      yield directory
    end
  end

  def test_accepts_a_manifest_whose_assets_exist
    with_assets { |directory| assert(FrontendAssets.verify!(directory)) }
  end

  def test_rejects_a_missing_manifest
    with_assets do |directory|
      FileUtils.rm(File.join(directory, "assets", "manifest.json"))

      error = assert_raises(FrontendAssets::Error) { FrontendAssets.verify!(directory) }
      assert_includes(error.message, "missing")
    end
  end

  def test_rejects_a_manifest_with_a_missing_referenced_asset
    with_assets do |directory|
      FileUtils.rm(File.join(directory, "assets", "javascript", "app.js"))

      error = assert_raises(FrontendAssets::Error) { FrontendAssets.verify!(directory) }
      assert_includes(error.message, "app.js")
    end
  end

  def test_rejects_invalid_or_unsafe_manifest_entries
    with_assets do |directory|
      manifest = File.join(directory, "assets", "manifest.json")
      File.write(
        manifest,
        JSON.generate("javascript" => ["../outside.js"], "stylesheets" => ["app.css"]),
      )

      error = assert_raises(FrontendAssets::Error) { FrontendAssets.verify!(directory) }
      assert_includes(error.message, "invalid asset name")

      File.write(manifest, "not json")
      error = assert_raises(FrontendAssets::Error) { FrontendAssets.verify!(directory) }
      assert_includes(error.message, "invalid")

      File.write(manifest, "null")
      error = assert_raises(FrontendAssets::Error) { FrontendAssets.verify!(directory) }
      assert_includes(error.message, "invalid")
    end
  end
end

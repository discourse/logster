# frozen_string_literal: true

require_relative "test_helper"
require_relative "../frontend_assets"
require "fileutils"
require "json"
require "tmpdir"

class TestFrontendAssets < Minitest::Test
  MANIFEST = {
    "_runtime.js" => {
      "file" => "assets/runtime.js",
    },
    "index.html" => {
      "file" => "assets/app.js",
      "isEntry" => true,
      "imports" => ["_runtime.js"],
      "css" => ["assets/app.css"],
    },
  }.freeze

  def with_assets
    Dir.mktmpdir do |directory|
      assets = File.join(directory, "assets")
      FileUtils.mkdir_p(File.join(assets, "javascript"))
      FileUtils.mkdir_p(File.join(assets, "stylesheets"))
      %w[app.js runtime.js].each { |name| File.write(File.join(assets, "javascript", name), "") }
      File.write(File.join(assets, "stylesheets", "app.css"), "")
      File.write(File.join(assets, "manifest.json"), JSON.generate(MANIFEST))
      File.write(File.join(assets, "logster-config.json"), JSON.generate("rootURL" => "/logs/"))
      yield directory, assets
    end
  end

  def test_accepts_a_manifest_whose_assets_exist
    with_assets { |directory, _| assert(FrontendAssets.verify!(directory)) }
  end

  def test_rejects_a_missing_manifest
    with_assets do |directory, assets|
      FileUtils.rm(File.join(assets, "manifest.json"))

      error = assert_raises(FrontendAssets::Error) { FrontendAssets.verify!(directory) }
      assert_includes(error.message, "missing")
    end
  end

  def test_rejects_a_missing_client_application_config
    with_assets do |directory, assets|
      FileUtils.rm(File.join(assets, "logster-config.json"))

      error = assert_raises(FrontendAssets::Error) { FrontendAssets.verify!(directory) }
      assert_includes(error.message, "logster-config.json")
    end
  end

  def test_rejects_a_manifest_with_a_missing_entry_chunk
    with_assets do |directory, assets|
      FileUtils.rm(File.join(assets, "javascript", "app.js"))

      error = assert_raises(FrontendAssets::Error) { FrontendAssets.verify!(directory) }
      assert_includes(error.message, "app.js")
    end
  end

  def test_rejects_a_manifest_with_a_missing_imported_chunk
    with_assets do |directory, assets|
      FileUtils.rm(File.join(assets, "javascript", "runtime.js"))

      error = assert_raises(FrontendAssets::Error) { FrontendAssets.verify!(directory) }
      assert_includes(error.message, "runtime.js")
    end
  end

  def test_rejects_a_manifest_with_a_missing_stylesheet
    with_assets do |directory, assets|
      FileUtils.rm(File.join(assets, "stylesheets", "app.css"))

      error = assert_raises(FrontendAssets::Error) { FrontendAssets.verify!(directory) }
      assert_includes(error.message, "app.css")
    end
  end

  def test_rejects_a_build_with_no_entry_chunk
    with_assets do |directory, assets|
      File.write(File.join(assets, "manifest.json"), JSON.generate("_runtime.js" => {}))

      error = assert_raises(FrontendAssets::Error) { FrontendAssets.verify!(directory) }
      assert_includes(error.message, "no entry chunk")
    end
  end

  def test_rejects_invalid_or_unsafe_manifest_entries
    with_assets do |directory, assets|
      manifest = File.join(assets, "manifest.json")
      File.write(
        manifest,
        JSON.generate("index.html" => { "file" => "../outside.js", "isEntry" => true }),
      )
      error = assert_raises(FrontendAssets::Error) { FrontendAssets.verify!(directory) }
      assert_includes(error.message, "missing")

      File.write(manifest, "not json")
      error = assert_raises(FrontendAssets::Error) { FrontendAssets.verify!(directory) }
      assert_includes(error.message, "invalid")

      File.write(manifest, "null")
      error = assert_raises(FrontendAssets::Error) { FrontendAssets.verify!(directory) }
      assert_includes(error.message, "invalid")
    end
  end
end

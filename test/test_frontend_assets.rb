# frozen_string_literal: true

require_relative "test_helper"
require_relative "../frontend_assets"
require "fileutils"
require "json"
require "tmpdir"

class TestFrontendAssets < Minitest::Test
  # The shape Vite actually emits: the entry reaches its only chunk through
  # dynamicImports rather than imports, and vendor.js is named nowhere.
  MANIFEST = {
    "index.html" => {
      "file" => "assets/main-abc123.js",
      "isEntry" => true,
      "dynamicImports" => ["node_modules/@embroider/legacy-inspector-support/src/modules-4-12.js"],
      "css" => ["assets/main-def456.css"],
    },
    "node_modules/@embroider/legacy-inspector-support/src/modules-4-12.js" => {
      "file" => "assets/modules-4-12-ghi789.js",
      "isDynamicEntry" => true,
      "imports" => ["index.html"],
    },
  }.freeze

  SCRIPTS = %w[main-abc123.js modules-4-12-ghi789.js vendor.js].freeze

  def with_assets
    Dir.mktmpdir do |directory|
      assets = File.join(directory, "assets")
      FileUtils.mkdir_p(File.join(assets, "javascript"))
      FileUtils.mkdir_p(File.join(assets, "stylesheets"))
      SCRIPTS.each { |name| File.write(File.join(assets, "javascript", name), "") }
      File.write(File.join(assets, "stylesheets", "main-def456.css"), "")
      File.write(File.join(assets, "manifest.json"), JSON.generate(MANIFEST))
      File.write(File.join(assets, "logster-config.json"), JSON.generate("rootURL" => "/logs/"))
      yield directory, assets
    end
  end

  def assert_rejects(assets, fragment)
    error = assert_raises(FrontendAssets::Error) { FrontendAssets.verify!(File.dirname(assets)) }
    assert_includes(error.message, fragment)
  end

  def test_accepts_a_manifest_whose_assets_exist
    with_assets { |directory, _| assert(FrontendAssets.verify!(directory)) }
  end

  def test_rejects_a_missing_manifest
    with_assets do |_, assets|
      FileUtils.rm(File.join(assets, "manifest.json"))
      assert_rejects(assets, "missing")
    end
  end

  def test_rejects_a_missing_client_application_config
    with_assets do |_, assets|
      FileUtils.rm(File.join(assets, "logster-config.json"))
      assert_rejects(assets, "logster-config.json")
    end
  end

  def test_rejects_a_missing_entry_chunk
    with_assets do |_, assets|
      FileUtils.rm(File.join(assets, "javascript", "main-abc123.js"))
      assert_rejects(assets, "main-abc123.js")
    end
  end

  def test_rejects_a_missing_dynamically_imported_chunk
    with_assets do |_, assets|
      FileUtils.rm(File.join(assets, "javascript", "modules-4-12-ghi789.js"))
      assert_rejects(assets, "modules-4-12-ghi789.js")
    end
  end

  def test_rejects_a_missing_vendor_script
    with_assets do |_, assets|
      FileUtils.rm(File.join(assets, "javascript", "vendor.js"))
      assert_rejects(assets, "vendor.js")
    end
  end

  def test_rejects_a_missing_stylesheet
    with_assets do |_, assets|
      FileUtils.rm(File.join(assets, "stylesheets", "main-def456.css"))
      assert_rejects(assets, "main-def456.css")
    end
  end

  def test_rejects_a_manifest_with_no_entry_chunk
    with_assets do |_, assets|
      without_entry =
        MANIFEST.transform_values { |chunk| chunk.reject { |key, _| key == "isEntry" } }
      File.write(File.join(assets, "manifest.json"), JSON.generate(without_entry))
      assert_rejects(assets, "no entry chunk")
    end
  end

  def test_rejects_a_manifest_referring_to_a_chunk_it_does_not_describe
    with_assets do |_, assets|
      dangling = { "index.html" => MANIFEST.fetch("index.html").merge("imports" => ["absent.js"]) }
      File.write(File.join(assets, "manifest.json"), JSON.generate(dangling))
      assert_rejects(assets, "absent.js")
    end
  end

  def test_rejects_an_unreadable_manifest
    with_assets do |_, assets|
      manifest = File.join(assets, "manifest.json")

      File.write(manifest, "not json")
      assert_rejects(assets, "invalid")

      File.write(manifest, "null")
      assert_rejects(assets, "invalid")

      File.write(manifest, JSON.generate("index.html" => "a string"))
      assert_rejects(assets, "invalid")
    end
  end

  def test_rejects_a_development_build
    with_assets do |_, assets|
      development =
        MANIFEST.merge(
          "tests/index.html" => {
            "file" => "assets/tests-jkl012.js",
            "isEntry" => true,
            "css" => ["assets/tests-mno345.css"],
          },
        )
      File.write(File.join(assets, "manifest.json"), JSON.generate(development))
      assert_rejects(assets, "development build")
    end
  end

  def test_rejects_a_second_entry_whatever_it_is_called
    with_assets do |_, assets|
      two_entries =
        MANIFEST.merge(
          "spec/index.html" => {
            "file" => "assets/main-abc123.js",
            "isEntry" => true,
          },
        )
      File.write(File.join(assets, "manifest.json"), JSON.generate(two_entries))
      assert_rejects(assets, "development build")
    end
  end

  def test_rejects_a_chunk_that_names_no_file
    with_assets do |_, assets|
      fileless =
        MANIFEST.merge(
          "index.html" => MANIFEST.fetch("index.html").reject { |key, _| key == "file" },
        )
      File.write(File.join(assets, "manifest.json"), JSON.generate(fileless))
      assert_rejects(assets, "names no file")
    end
  end

  def test_rejects_a_chunk_naming_assets_the_build_does_not_package
    with_assets do |_, assets|
      with_font =
        MANIFEST.merge(
          "index.html" =>
            MANIFEST.fetch("index.html").merge("assets" => ["assets/font-pqr678.woff2"]),
        )
      File.write(File.join(assets, "manifest.json"), JSON.generate(with_font))
      assert_rejects(assets, "does not package")
    end
  end

  def test_accepts_files_in_the_directories_that_no_chunk_names
    with_assets do |directory, assets|
      File.write(File.join(assets, "javascript", "left-behind.js"), "")

      assert(FrontendAssets.verify!(directory))
    end
  end
end

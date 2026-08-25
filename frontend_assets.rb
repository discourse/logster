# frozen_string_literal: true

require "json"

module FrontendAssets
  class Error < StandardError
  end

  ASSET_NAME = /\A[a-zA-Z0-9._-]+\z/
  DIRECTORY_FOR = { ".css" => "stylesheets" }.freeze

  def self.verify!(root)
    assets_directory = File.join(root, "assets")
    manifest = read_json(assets_directory, "manifest.json")
    read_json(assets_directory, "logster-config.json")

    entry = manifest.values.find { |chunk| chunk.is_a?(Hash) && chunk["isEntry"] }
    raise Error, "Frontend asset manifest names no entry chunk" unless entry

    referenced(manifest, entry).each do |name|
      unless ASSET_NAME.match?(name)
        raise Error, "Frontend asset manifest contains an invalid asset name: #{name.inspect}"
      end

      directory = DIRECTORY_FOR.fetch(File.extname(name), "javascript")
      unless File.file?(File.join(assets_directory, directory, name))
        raise Error, "Frontend asset referenced by the manifest is missing: #{name}"
      end
    end

    true
  end

  def self.read_json(assets_directory, name)
    path = File.join(assets_directory, name)
    unless File.file?(path)
      raise Error, "Frontend asset #{name} is missing; run build_client_app.sh before releasing"
    end

    parsed = JSON.parse(File.read(path))
    raise Error, "Frontend asset #{name} is invalid" unless parsed.is_a?(Hash)

    parsed
  rescue JSON::ParserError => error
    raise Error, "Frontend asset #{name} is invalid: #{error.message}"
  end

  def self.referenced(manifest, entry, names = [], seen = {})
    names << File.basename(entry.fetch("file"))
    Array(entry["css"]).each { |href| names << File.basename(href) }

    Array(entry["imports"]).each do |key|
      next if seen[key]
      seen[key] = true

      chunk = manifest[key]
      raise Error, "Frontend asset manifest is missing chunk #{key}" unless chunk

      referenced(manifest, chunk, names, seen)
    end

    names
  rescue KeyError, TypeError => error
    raise Error, "Frontend asset manifest is invalid: #{error.message}"
  end
end

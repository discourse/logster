# frozen_string_literal: true

require "json"

module FrontendAssets
  class Error < StandardError
  end

  ASSET_DIRECTORIES = { "javascript" => "javascript", "stylesheets" => "stylesheets" }.freeze
  ASSET_NAME = /\A[a-zA-Z0-9._-]+\z/

  def self.verify!(root)
    assets_directory = File.join(root, "assets")
    manifest_path = File.join(assets_directory, "manifest.json")
    unless File.file?(manifest_path)
      raise Error, "Frontend asset manifest is missing; run build_client_app.sh before releasing"
    end

    manifest = JSON.parse(File.read(manifest_path))
    raise Error, "Frontend asset manifest is invalid" unless manifest.is_a?(Hash)

    ASSET_DIRECTORIES.each do |type, directory|
      names = manifest.fetch(type)
      raise Error, "Frontend asset manifest has invalid #{type} entries" unless names.is_a?(Array)

      names.each do |name|
        unless String === name && ASSET_NAME.match?(name) && !%w[. ..].include?(name)
          raise Error, "Frontend asset manifest contains an invalid asset name: #{name.inspect}"
        end

        path = File.join(assets_directory, directory, name)
        unless File.file?(path)
          raise Error, "Frontend asset referenced by the manifest is missing: #{name}"
        end
      end
    end

    unless manifest["config"].is_a?(Hash)
      raise Error, "Frontend asset manifest has invalid client application config"
    end

    true
  rescue JSON::ParserError, KeyError, TypeError => error
    raise Error, "Frontend asset manifest is invalid: #{error.message}"
  end
end

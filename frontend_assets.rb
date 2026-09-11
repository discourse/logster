# frozen_string_literal: true

require "json"

module FrontendAssets
  class Error < StandardError
  end

  # classicEmberSupport emits this outside dist/assets, so no manifest chunk
  # ever names it.
  UNMANIFESTED = %w[vendor.js].freeze
  DIRECTORY_FOR = { ".css" => "stylesheets" }.freeze

  def self.verify!(root)
    assets_directory = File.join(root, "assets")
    manifest = read_json(assets_directory, "manifest.json")
    read_json(assets_directory, "logster-config.json")

    manifest.each do |key, chunk|
      raise Error, "Frontend asset manifest chunk #{key} is invalid" unless chunk.is_a?(Hash)
    end

    # The viewer renders whichever entry it finds first, so a second one means
    # a development build, where the test bundle is an entry of its own.
    entries = manifest.each_value.count { |chunk| chunk["isEntry"] }
    raise Error, "Frontend asset manifest names no entry chunk" if entries.zero?
    if entries > 1
      raise Error, "Frontend assets came from a development build; rebuild for production"
    end

    (referenced(manifest) + UNMANIFESTED).each do |name|
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

  # Every file the build copies into assets/ lands in one of two flat
  # directories, so which chunk imports which only matters for spotting a
  # manifest that points at a chunk it does not describe.
  def self.referenced(manifest)
    manifest
      .flat_map do |key, chunk|
        [*chunk["imports"], *chunk["dynamicImports"]].each do |reference|
          unless manifest.key?(reference)
            raise Error, "Frontend asset manifest is missing chunk #{reference}"
          end
        end

        # build_client_app.sh copies scripts and stylesheets, so a chunk that
        # pulls in a font or an image has outgrown it.
        unless Array(chunk["assets"]).empty?
          raise Error,
                "Frontend asset manifest chunk #{key} names assets the build does not package"
        end

        file = chunk["file"]
        raise Error, "Frontend asset manifest chunk #{key} names no file" unless file

        [file, *chunk["css"]]
      end
      .map { |href| File.basename(href) }
      .uniq
  end
end

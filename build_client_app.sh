#!/bin/bash

set -euo pipefail

environment="${1:-production}"
root_dir="$(cd "$(dirname "$0")" && pwd)"
client_dir="$root_dir/client-app"
temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/logster-assets.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT

rm -rf "$client_dir/dist"
(
  cd "$client_dir"
  ./node_modules/.bin/ember build --environment="$environment"
)

mkdir -p "$temporary_dir/javascript" "$temporary_dir/stylesheets"
cp "$client_dir"/dist/assets/*.js "$temporary_dir/javascript/"
cp "$client_dir"/dist/assets/*.css "$temporary_dir/stylesheets/"
node "$client_dir/scripts/build-logster-manifest.mjs" \
  "$client_dir/dist/index.html" \
  "$temporary_dir/manifest.json"

find "$root_dir/assets/javascript" -maxdepth 1 -type f ! -name .gitkeep -delete
find "$root_dir/assets/stylesheets" -maxdepth 1 -type f ! -name .gitkeep -delete
cp "$temporary_dir"/javascript/* "$root_dir/assets/javascript/"
cp "$temporary_dir"/stylesheets/* "$root_dir/assets/stylesheets/"
mv "$temporary_dir/manifest.json" "$root_dir/assets/manifest.json"

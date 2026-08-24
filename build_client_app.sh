#!/bin/bash

set -euo pipefail

environment="${1:-production}"
root_dir="$(cd "$(dirname "$0")" && pwd)"
client_dir="$root_dir/client-app"

node "$client_dir/scripts/ensure-dependencies.mjs"
rm -rf "$client_dir/dist"
(
  cd "$client_dir"
  ./node_modules/.bin/ember build --environment="$environment"
)

find "$root_dir/assets/javascript" -maxdepth 1 -type f ! -name .gitkeep -delete
find "$root_dir/assets/stylesheets" -maxdepth 1 -type f ! -name .gitkeep -delete
cp "$client_dir"/dist/assets/*.js "$root_dir/assets/javascript/"
cp "$client_dir"/dist/assets/*.css "$root_dir/assets/stylesheets/"
node "$client_dir/scripts/build-logster-manifest.mjs" \
  "$client_dir/dist/index.html" \
  "$root_dir/assets/manifest.json"

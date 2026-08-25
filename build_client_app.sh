#!/bin/bash

set -euo pipefail

environment="${1:-production}"
root_dir="$(cd "$(dirname "$0")" && pwd)"
client_dir="$root_dir/client-app"

node "$client_dir/scripts/ensure-dependencies.mjs"
rm -rf "$client_dir/dist"
(
  cd "$client_dir"
  ./node_modules/.bin/vite build --mode "$environment"
)

find "$root_dir/assets/javascript" -maxdepth 1 -type f ! -name .gitkeep -delete
find "$root_dir/assets/stylesheets" -maxdepth 1 -type f ! -name .gitkeep -delete
cp "$client_dir"/dist/assets/*.js "$root_dir/assets/javascript/"
cp "$client_dir"/dist/assets/*.css "$root_dir/assets/stylesheets/"
# The EmberENV script classicEmberSupport emits lives outside dist/assets.
cp "$client_dir"/dist/@embroider/virtual/vendor.js "$root_dir/assets/javascript/"
# The viewer renders its own HTML from Vite's build manifest and the
# application config the build emits beside it.
cp "$client_dir/dist/.vite/manifest.json" "$root_dir/assets/manifest.json"
cp "$client_dir/dist/logster-config.json" "$root_dir/assets/logster-config.json"

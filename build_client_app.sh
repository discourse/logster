#!/bin/bash

set -euo pipefail

environment="${1:-production}"
root_dir="$(cd "$(dirname "$0")" && pwd)"
client_dir="$root_dir/client-app"
temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/logster-assets.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT

# pnpm writes the lockfile it installed from into node_modules, so comparing the
# two says whether the install is current. A wiped node_modules loses the copy.
if ! cmp -s "$client_dir/node_modules/.pnpm/lock.yaml" "$client_dir/pnpm-lock.yaml"; then
  pnpm install --dir "$client_dir"
fi
rm -rf "$client_dir/dist"
(
  cd "$client_dir"
  pnpm exec vite build --mode "$environment"
)

# A development build also emits the test bundle, which has no business shipping.
mkdir -p "$temporary_dir/javascript" "$temporary_dir/stylesheets"
find "$client_dir/dist/assets" -maxdepth 1 -type f -name "*.js" \
  ! -name "tests-*.js" -exec cp {} "$temporary_dir/javascript/" \;
find "$client_dir/dist/assets" -maxdepth 1 -type f -name "*.css" \
  ! -name "tests-*.css" -exec cp {} "$temporary_dir/stylesheets/" \;
cp "$client_dir"/dist/@embroider/virtual/vendor.js "$temporary_dir/javascript/"
cp "$client_dir/dist/.vite/manifest.json" "$temporary_dir/manifest.json"
cp "$client_dir/dist/logster-config.json" "$temporary_dir/logster-config.json"

find "$root_dir/assets/javascript" -maxdepth 1 -type f ! -name .gitkeep -delete
find "$root_dir/assets/stylesheets" -maxdepth 1 -type f ! -name .gitkeep -delete
cp "$temporary_dir"/javascript/* "$root_dir/assets/javascript/"
cp "$temporary_dir"/stylesheets/* "$root_dir/assets/stylesheets/"
mv "$temporary_dir/manifest.json" "$root_dir/assets/manifest.json"
mv "$temporary_dir/logster-config.json" "$root_dir/assets/logster-config.json"

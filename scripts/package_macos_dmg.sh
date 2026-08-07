#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
app_path="$project_dir/dist/Astrolog-AS.app"

if [[ ! -d "$app_path" ]]; then
  echo "Missing $app_path; run ./scripts/build_macos_app.sh first." >&2
  exit 1
fi

build_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_path/Contents/Info.plist")
output_path="$project_dir/dist/Astrolog-AS-$build_version-arm64.dmg"
staging_path=$(mktemp -d "${TMPDIR:-/tmp}/astrolog-as-dmg.XXXXXX")
trap 'rm -rf "$staging_path"' EXIT

ditto "$app_path" "$staging_path/Astrolog-AS.app"
ln -s /Applications "$staging_path/Applications"

hdiutil create \
  -volname "Astrolog-AS" \
  -srcfolder "$staging_path" \
  -ov \
  -format UDZO \
  "$output_path"
hdiutil verify "$output_path"

echo "Built $output_path"

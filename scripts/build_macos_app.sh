#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
app_path="$project_dir/dist/Astrolog-AS.app"
contents_path="$app_path/Contents"
resources_path="$contents_path/Resources"
build_path="$project_dir/build/macos"
iconset_path="$build_path/AppIcon.iconset"
asset_catalog_path="$build_path/Assets.xcassets"
compiled_assets_path="$build_path/compiled-assets"

cd "$project_dir"

jobs=$(sysctl -n hw.ncpu 2>/dev/null || echo 8)
make -j"$jobs" ARCHFLAGS="-arch arm64"

rm -rf "$app_path" "$build_path"
mkdir -p "$contents_path/MacOS" "$resources_path" "$build_path"

developer_dir=$(xcode-select -p)
if [[ "$developer_dir" == */CommandLineTools ]]; then
  xcode_app=$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" | head -n 1)
  if [[ -n "$xcode_app" && -d "$xcode_app/Contents/Developer" ]]; then
    developer_dir="$xcode_app/Contents/Developer"
  else
    applications_dir="${developer_dir:h:h:h}Applications"
    for candidate in "$applications_dir"/*.app(N); do
      candidate_developer="$candidate/Contents/Developer"
      if DEVELOPER_DIR="$candidate_developer" xcrun --find actool >/dev/null 2>&1; then
        developer_dir="$candidate_developer"
        break
      fi
    done
  fi
fi
export DEVELOPER_DIR="$developer_dir"
export CLANG_MODULE_CACHE_PATH="$build_path/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$build_path/module-cache"

xcrun swiftc \
  -swift-version 5 \
  -parse-as-library \
  -target arm64-apple-macos14.0 \
  -O \
  -framework AppKit \
  -framework SwiftUI \
  -framework UniformTypeIdentifiers \
  -framework WebKit \
  macos/AstrologTime.swift \
  macos/ChartResult.swift \
  macos/ChartRequest.swift \
  macos/WheelTooltips.swift \
  macos/SolarSystemZoom.swift \
  macos/AstrologApp.swift \
  -o "$contents_path/MacOS/Astrolog-AS"

xcrun swiftc \
  -swift-version 5 \
  -target arm64-apple-macos14.0 \
  -framework AppKit \
  macos/GenerateIcon.swift \
  -o "$build_path/generate-icon"

"$build_path/generate-icon" "$iconset_path"
mkdir -p "$asset_catalog_path/AppIcon.appiconset" "$compiled_assets_path"
cp "$iconset_path"/*.png "$asset_catalog_path/AppIcon.appiconset/"
cp macos/AppIconContents.json "$asset_catalog_path/AppIcon.appiconset/Contents.json"
if ! xcrun actool "$asset_catalog_path" \
  --compile "$compiled_assets_path" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$build_path/asset-info.plist" \
  >"$build_path/actool.log" 2>&1; then
  cat "$build_path/actool.log" >&2
  exit 1
fi
cp "$compiled_assets_path/AppIcon.icns" "$resources_path/AppIcon.icns"
cp "$compiled_assets_path/Assets.car" "$resources_path/Assets.car"

cp macos/Info.plist "$contents_path/Info.plist"
cp astrolog "$resources_path/astrolog-cli"
chmod 755 "$contents_path/MacOS/Astrolog-AS" "$resources_path/astrolog-cli"

runtime_files=(
  astrolog.as atlas.as timezone.as astexo.csv earth.bmp sefstars.txt seorbel.txt
  mazegame.as astrolog.htm changes.htm license.htm
)
for file in $runtime_files; do
  cp "$file" "$resources_path/$file"
done
# Astrolog prepends the full executable directory to each relative -Yi entry.
# Keeping only the runtime ephemeris entry avoids overflowing its legacy
# 255-character Swiss Ephemeris search-path buffer inside an app bundle.
sed -i '' -e '/^-Yi2 /d' -e '/^-Yi3 /d' "$resources_path/astrolog.as"
ditto ephem "$resources_path/ephem"
ditto font "$resources_path/font"

codesign --force --deep --sign - "$app_path"
codesign --verify --deep --strict "$app_path"
plutil -lint "$contents_path/Info.plist"

echo "Built $app_path"

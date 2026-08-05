#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
build_path="$project_dir/build/macos-tests"
developer_dir=$(xcode-select -p)

if [[ "$developer_dir" == */CommandLineTools ]]; then
  xcode_app=$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" | head -n 1)
  if [[ -n "$xcode_app" && -d "$xcode_app/Contents/Developer" ]]; then
    developer_dir="$xcode_app/Contents/Developer"
  else
    applications_dir="${developer_dir:h:h:h}Applications"
    for candidate in "$applications_dir"/*.app(N); do
      candidate_developer="$candidate/Contents/Developer"
      if DEVELOPER_DIR="$candidate_developer" xcrun --find swiftc >/dev/null 2>&1; then
        developer_dir="$candidate_developer"
        break
      fi
    done
  fi
fi

rm -rf "$build_path"
mkdir -p "$build_path/module-cache"
export DEVELOPER_DIR="$developer_dir"
export CLANG_MODULE_CACHE_PATH="$build_path/module-cache"

cd "$project_dir"
xcrun swiftc \
  -swift-version 5 \
  -parse-as-library \
  -target arm64-apple-macos14.0 \
  macos/AstrologTime.swift \
  macos/tests/AstrologTimeTests.swift \
  -o "$build_path/AstrologTimeTests"

"$build_path/AstrologTimeTests"

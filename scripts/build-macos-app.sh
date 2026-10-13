#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
build_root="$project_root/build/macos"
staging_root="$(mktemp -d /private/tmp/zhiti-macos.XXXXXX)"
app_path="$staging_root/知题安全版.app"
build_arch="$(uname -m)"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources/assets" "$build_root/module-cache"
swiftc -swift-version 5 -O -target "$build_arch-apple-macos12.0" -module-cache-path "$build_root/module-cache" \
  -framework AppKit -framework WebKit -framework Security \
  "$project_root/desktop/macos/SecurityCore.swift" "$project_root/desktop/macos/App.swift" \
  -o "$app_path/Contents/MacOS/ZHITI"
cp -X "$project_root/desktop/macos/Info.plist" "$app_path/Contents/Info.plist"
cp -X "$project_root/index.html" "$app_path/Contents/Resources/index.html"
cp -X "$project_root/assets/cover.svg" "$app_path/Contents/Resources/assets/cover.svg"
# 仅移除生成包内会导致签名失败的 Finder 元数据，不改变隔离属性。
xattr -dr com.apple.FinderInfo "$app_path" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$app_path" 2>/dev/null || true
xattr -d com.apple.FinderInfo "$app_path" 2>/dev/null || true
codesign --force --sign - --identifier org.zhiti.learning.secure "$app_path"
codesign --verify --deep --strict "$app_path"
ditto -c -k --norsrc --keepParent "$app_path" "$build_root/知题安全版.zip"
printf '%s\n' "$app_path"
printf '%s\n' "$build_root/知题安全版.zip"

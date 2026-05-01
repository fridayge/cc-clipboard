#!/bin/bash
# build.sh — 构建 CCClipboard.app 并打包为 .zip
set -euo pipefail

VERSION="${1:-1.0.0}"
PRODUCT="CCClipboard"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$PRODUCT.app"

rm -rf "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"

# CLT SwiftBridging 重复定义修复
VFS_FLAGS=()
if [ -f /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap ] \
   && [ -f /Library/Developer/CommandLineTools/usr/include/swift/bridging.modulemap ]; then
    VFS_YAML="$SCRIPT_DIR/.vfs-bridging-overlay.yaml"
    cat > "$VFS_YAML" << 'EOF'
{
  "version": 0,
  "roots": [
    {
      "name": "/Library/Developer/CommandLineTools/usr/include/swift/module.modulemap",
      "type": "file",
      "external-contents": "/Library/Developer/CommandLineTools/usr/include/swift/bridging.modulemap"
    }
  ]
}
EOF
    VFS_FLAGS=(-vfsoverlay "$VFS_YAML")
    echo "Detected CLT SwiftBridging bug, applying VFS overlay"
fi

# 编译
swiftc \
    "${VFS_FLAGS[@]}" \
    -parse-as-library \
    -target arm64-apple-macosx13.0 \
    -framework SwiftUI \
    -framework AppKit \
    -O -whole-module-optimization \
    "$SCRIPT_DIR/cc-clipboard.swift" \
    -o "$APP_BUNDLE/Contents/MacOS/$PRODUCT"

# Info.plist
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/"

# 清理 VFS 临时文件
rm -f "$SCRIPT_DIR/.vfs-bridging-overlay.yaml"

# 打包
cd "$DIST_DIR"
zip -r "${PRODUCT}-${VERSION}.zip" "${PRODUCT}.app"
echo "Done: $DIST_DIR/${PRODUCT}-${VERSION}.zip"

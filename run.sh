#!/bin/bash
set -e
cd "$(dirname "$0")"

# Rebuild the icon if the source SVG is newer than the bundled .icns
if [ icon/icon.svg -nt MyCommander.app/Contents/Resources/MyCommander.icns ]; then
    echo "Regenerating app icon..."
    swift icon/make_icns.swift
    cp -f icon/MyCommander.icns MyCommander.app/Contents/Resources/MyCommander.icns
    touch MyCommander.app
fi

swift build -c release

# Copy binary
cp -f .build/release/MyCommander MyCommander.app/Contents/MacOS/MyCommander

# Embed Sparkle.framework
BUILD_DIR=".build/arm64-apple-macosx/release"
if [ ! -d "$BUILD_DIR/Sparkle.framework" ]; then
    BUILD_DIR=".build/release"
fi
mkdir -p MyCommander.app/Contents/Frameworks
rm -rf MyCommander.app/Contents/Frameworks/Sparkle.framework
cp -R "$BUILD_DIR/Sparkle.framework" MyCommander.app/Contents/Frameworks/

# Ensure the binary can find Sparkle at Contents/Frameworks
install_name_tool -add_rpath "@executable_path/../Frameworks" MyCommander.app/Contents/MacOS/MyCommander 2>/dev/null || true

open MyCommander.app

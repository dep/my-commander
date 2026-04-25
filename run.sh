#!/bin/bash
set -e
cd "$(dirname "$0")"

APP="My Commander.app"

# Rebuild the icon if the source SVG is newer than the bundled .icns
if [ icon/icon.svg -nt "$APP/Contents/Resources/MyCommander.icns" ]; then
    echo "Regenerating app icon..."
    swift icon/make_icns.swift
    cp -f icon/MyCommander.icns "$APP/Contents/Resources/MyCommander.icns"
    touch "$APP"
fi

swift build -c release

# Copy binary (Swift target is still "MyCommander"; bundle executable is "My Commander")
cp -f .build/release/MyCommander "$APP/Contents/MacOS/My Commander"

# Embed Sparkle.framework
BUILD_DIR=".build/arm64-apple-macosx/release"
if [ ! -d "$BUILD_DIR/Sparkle.framework" ]; then
    BUILD_DIR=".build/release"
fi
mkdir -p "$APP/Contents/Frameworks"
rm -rf "$APP/Contents/Frameworks/Sparkle.framework"
cp -R "$BUILD_DIR/Sparkle.framework" "$APP/Contents/Frameworks/"

# Ensure the binary can find Sparkle at Contents/Frameworks
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/My Commander" 2>/dev/null || true

open "$APP"

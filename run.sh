#!/bin/bash
set -e
cd "$(dirname "$0")"
swift build -c release
cp -f .build/release/MyCommander MyCommander.app/Contents/MacOS/MyCommander
open MyCommander.app

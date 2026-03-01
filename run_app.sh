#!/bin/bash
set -e

# simple helper script to build and run Jarvis on macOS
cd "$(dirname "$0")/Jarvis"

xcodebuild -project Jarvis.xcodeproj -scheme Jarvis -destination 'platform=macOS' build

APP=$(find ~/Library/Developer/Xcode/DerivedData/Jarvis-* -name Jarvis.app | head -1)
if [[ -n "$APP" ]]; then
    open "$APP"
else
    echo "built app not found"
    exit 1
fi

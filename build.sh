#!/bin/bash

# Build script for Nolon

# Ensure Xcode tools are selected
if ! xcode-select -p &> /dev/null; then
    echo "Error: Xcode tools not found. Please install Xcode."
    exit 1
fi

echo "🚀 Building Nolon..."

xcodebuild -project nolon.xcodeproj \
           -scheme nolon \
           -configuration Release \
           -destination 'platform=macOS' \
           clean build

if [ $? -eq 0 ]; then
    echo "✅ Build succeeded!"
else
    echo "❌ Build failed."
    exit 1
fi

#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$DIR/bin"
mkdir -p "$DIR/cores"

echo "=========================================================="
echo " Building SaturnMac Standalone Apple Silicon Runner"
echo " Frameworks: Cocoa + Metal + MetalKit + GameController + CoreAudio"
echo "=========================================================="

clang -O3 -fobjc-arc \
    -framework Cocoa \
    -framework Metal \
    -framework MetalKit \
    -framework AudioToolbox \
    -framework GameController \
    -I"$DIR" \
    "$DIR/saturn_runner.m" -o "$DIR/bin/saturn_runner"

# Download the Apple Silicon Saturn core if not already present
if [ ! -f "$DIR/cores/yabasanshiro_libretro.dylib" ]; then
    echo "Downloading Apple Silicon Saturn core (yabasanshiro)..."
    curl -sL "https://buildbot.libretro.com/nightly/apple/osx/arm64/latest/yabasanshiro_libretro.dylib.zip" -o "$DIR/cores/core.zip"
    unzip -q -o "$DIR/cores/core.zip" -d "$DIR/cores"
    rm -f "$DIR/cores/core.zip"
fi

# Remove quarantine flags and sign ad-hoc for Apple Silicon (ARM64 requirement)
xattr -cr "$DIR" 2>/dev/null || true
codesign --force --sign - "$DIR/bin/saturn_runner" 2>/dev/null || true
for dylib in "$DIR/cores"/*.dylib; do
    if [ -f "$dylib" ]; then
        codesign --force --sign - "$dylib" 2>/dev/null || true
    fi
done

echo "✅ SaturnMac Standalone Runner ready and codesigned at: $DIR/bin/saturn_runner"

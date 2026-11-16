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
    -framework QuartzCore \
    -framework Metal \
    -framework MetalKit \
    -framework AudioToolbox \
    -framework GameController \
    -I"$DIR" \
    "$DIR/saturn_runner.m" -o "$DIR/bin/saturn_runner"

# Download Apple Silicon Saturn cores (yabause for software/MetalKit, and yabasanshiro)
if [ ! -f "$DIR/cores/yabause_libretro.dylib" ]; then
    echo "Downloading Apple Silicon Saturn core (yabause)..."
    curl -sL "https://buildbot.libretro.com/nightly/apple/osx/arm64/latest/yabause_libretro.dylib.zip" -o "$DIR/cores/yabause.zip"
    unzip -q -o "$DIR/cores/yabause.zip" -d "$DIR/cores"
    rm -f "$DIR/cores/yabause.zip"
fi

if [ ! -f "$DIR/cores/yabasanshiro_libretro.dylib" ]; then
    echo "Downloading Apple Silicon Saturn core (yabasanshiro)..."
    curl -sL "https://buildbot.libretro.com/nightly/apple/osx/arm64/latest/yabasanshiro_libretro.dylib.zip" -o "$DIR/cores/yabasanshiro.zip"
    unzip -q -o "$DIR/cores/yabasanshiro.zip" -d "$DIR/cores"
    rm -f "$DIR/cores/yabasanshiro.zip"
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

# Build standalone SaturnMac.app GUI application
APP_DIR="$DIR/../dist/SaturnMac.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources/cores"
cp "$DIR/bin/saturn_runner" "$APP_DIR/Contents/MacOS/SaturnMac"
chmod +x "$APP_DIR/Contents/MacOS/SaturnMac"
cp "$DIR/cores"/*.dylib "$APP_DIR/Contents/Resources/cores/" 2>/dev/null || true

cat << 'EOF' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>SaturnMac</string>
    <key>CFBundleDisplayName</key>
    <string>SaturnMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.saturnmac.launcher</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleExecutable</key>
    <string>SaturnMac</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "APPL????" > "$APP_DIR/Contents/PkgInfo"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo "🎉 Standalone SaturnMac.app GUI application ready at: $APP_DIR"

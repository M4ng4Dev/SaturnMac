use crate::icns::IcnsBuilder;
use crate::parser::SaturnGameInfo;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppBundleOptions {
    pub internal_resolution: u32,   // 1 = Native 240p/480p, 2 = 2x, 4 = 4x Retina
    pub metal_rendering: bool,       // Use Metal graphics pipeline
    pub promotion_120hz: bool,       // Adaptive ProMotion 120Hz frame pacing
    pub widescreen_anamorphic: bool, // 16:9 widescreen geometry mode
    pub crt_shader: bool,            // Metal CRT phosphor/scanlines filter
    pub icon_png_path: Option<PathBuf>,
}

impl Default for AppBundleOptions {
    fn default() -> Self {
        Self {
            internal_resolution: 2,
            metal_rendering: true,
            promotion_120hz: true,
            widescreen_anamorphic: false,
            crt_shader: false,
            icon_png_path: None,
        }
    }
}

pub struct AppBundler;

impl AppBundler {
    /// Generate a standalone .app bundle for macOS.
    pub fn create_app_bundle<P: AsRef<Path>, O: AsRef<Path>>(
        rom_path: P,
        info: &SaturnGameInfo,
        output_dir: O,
        options: &AppBundleOptions,
    ) -> Result<PathBuf> {
        let rom_path = rom_path.as_ref();
        let output_dir = output_dir.as_ref();

        // Sanitize app name
        let clean_title = sanitize_filename(&info.title);
        let app_name = if clean_title.is_empty() {
            format!("Saturn_{}", info.product_id.replace(['/', '\\', ' '], "_"))
        } else {
            clean_title
        };

        let bundle_name = format!("{}.app", app_name);
        let bundle_root = output_dir.join(&bundle_name);
        let contents_dir = bundle_root.join("Contents");
        let macos_dir = contents_dir.join("MacOS");
        let resources_dir = contents_dir.join("Resources");
        let game_dir = resources_dir.join("Game");
        let config_dir = resources_dir.join("Config");

        // Create directories
        fs::create_dir_all(&macos_dir)?;
        fs::create_dir_all(&game_dir)?;
        fs::create_dir_all(&config_dir)?;

        // 1. Generate Info.plist
        let bundle_id = format!(
            "com.saturnmac.{}",
            info.product_id.to_lowercase().replace(['-', ' ', '_', '/'], "")
        );
        let plist_content = generate_info_plist(&app_name, &bundle_id, &info.version);
        fs::write(contents_dir.join("Info.plist"), plist_content)?;

        // 2. Generate PkgInfo
        fs::write(contents_dir.join("PkgInfo"), "APPL????")?;

        // 3. Generate AppIcon.icns
        let icns_bytes = if let Some(ref icon_path) = options.icon_png_path {
            if icon_path.exists() {
                let png = fs::read(icon_path)?;
                IcnsBuilder::from_png(&png)?
            } else {
                IcnsBuilder::default_saturn_icon()
            }
        } else {
            IcnsBuilder::default_saturn_icon()
        };
        fs::write(resources_dir.join("AppIcon.icns"), icns_bytes)?;

        // 4. Copy ROM files (handling CUE + BIN / multi-tracks)
        copy_rom_files(rom_path, &game_dir)?;

        // 5. Generate JSON game configuration
        let config_json = serde_json::to_string_pretty(&serde_json::json!({
            "game": info,
            "mac_optimizations": {
                "apple_silicon_arm64": true,
                "metal_rendering": options.metal_rendering,
                "internal_resolution": options.internal_resolution,
                "promotion_120hz": options.promotion_120hz,
                "crt_shader": options.crt_shader,
                "widescreen_16_9": options.widescreen_anamorphic,
                "game_controller_framework": true,
                "core_audio_low_latency": true,
                "save_dir": format!("~/Library/Application Support/SaturnMac/Saves/{}", info.product_id.trim())
            }
        }))?;
        fs::write(config_dir.join("saturn.json"), config_json)?;

        // 6. Generate the native macOS Launcher
        let launcher_path = macos_dir.join("Launcher");
        let launcher_script = generate_launcher_script(&app_name, info);
        fs::write(&launcher_path, launcher_script)?;

        // Make Launcher executable (permissions 0755)
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(&launcher_path, fs::Permissions::from_mode(0o755))?;
        }

        Ok(bundle_root)
    }
}

fn sanitize_filename(name: &str) -> String {
    name.chars()
        .filter(|c| c.is_alphanumeric() || *c == ' ' || *c == '-' || *c == '_')
        .collect::<String>()
        .trim()
        .to_string()
}

fn generate_info_plist(app_name: &str, bundle_id: &str, version: &str) -> String {
    format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>{app_name}</string>
    <key>CFBundleDisplayName</key>
    <string>{app_name}</string>
    <key>CFBundleIdentifier</key>
    <string>{bundle_id}</string>
    <key>CFBundleVersion</key>
    <string>{version}</string>
    <key>CFBundleShortVersionString</key>
    <string>{version}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleExecutable</key>
    <string>Launcher</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.action-games</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
    <key>GCSupportedGameControllers</key>
    <array>
        <dict>
            <key>ProfileName</key>
            <string>ExtendedGamepad</string>
        </dict>
        <dict>
            <key>ProfileName</key>
            <string>MicroGamepad</string>
        </dict>
    </array>
    <key>GCSupportsControllerUserInteraction</key>
    <true/>
</dict>
</plist>
"#
    )
}

fn generate_launcher_script(app_name: &str, info: &SaturnGameInfo) -> String {
    let region_flag = if info.region_codes.contains('J') {
        "jp"
    } else if info.region_codes.contains('E') {
        "eu"
    } else {
        "na"
    };

    format!(
        r#"#!/bin/bash
# SaturnMac Native App Launcher for Apple Silicon / macOS
# Game: {title} ({product_id})

DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCES="$DIR/Resources"
GAME_DIR="$RESOURCES/Game"
CONFIG="$RESOURCES/Config/saturn.json"
SAVES_DIR="$HOME/Library/Application Support/SaturnMac/Saves/{product_id}"

mkdir -p "$SAVES_DIR"

echo "=========================================="
echo " Starting {app_name} on macOS"
echo " Title: {title}"
echo " Product: {product_id} | Region: {region_flag}"
echo " Architecture: $(uname -m) (Apple Silicon / Metal Native)"
echo " Saves: $SAVES_DIR"
echo "=========================================="

# Locate primary game image (.cue, .bin, .iso, .chd)
ROM_TARGET=$(find "$GAME_DIR" -maxdepth 1 \( -name "*.cue" -o -name "*.chd" -o -name "*.iso" -o -name "*.bin" \) | head -n 1)

if [ -z "$ROM_TARGET" ]; then
    osascript -e 'display alert "SaturnMac Error" message "Game ROM files not found inside application bundle."'
    exit 1
fi

# Check for embedded engine or system runner
RUNNER="$RESOURCES/bin/saturn_runner"

if [ -x "$RUNNER" ]; then
    exec "$RUNNER" --rom "$ROM_TARGET" --config "$CONFIG" --save-path "$SAVES_DIR"
else
    # Fallback to OpenEmu / RetroArch or Mednafen if installed on the host
    if [ -x "/Applications/OpenEmu.app/Contents/MacOS/OpenEmu" ]; then
        open -a OpenEmu "$ROM_TARGET"
    elif [ -x "/Applications/RetroArch.app/Contents/MacOS/RetroArch" ]; then
        /Applications/RetroArch.app/Contents/MacOS/RetroArch -L "$HOME/Library/Application Support/RetroArch/cores/beetle_saturn_libretro.dylib" "$ROM_TARGET"
    else
        osascript -e 'display dialog "SaturnMac Application Bundle successfully created for {app_name}!\n\nTo play, ensure your Saturn core or runner is placed in Resources/bin or installed on macOS." buttons {{"OK"}} default button "OK" with title "{app_name}"'
    fi
fi
"#,
        app_name = app_name,
        title = info.title,
        product_id = info.product_id.trim(),
        region_flag = region_flag
    )
}

fn copy_rom_files(src_path: &Path, dest_dir: &Path) -> Result<()> {
    if src_path.is_dir() {
        for entry in fs::read_dir(src_path)? {
            let entry = entry?;
            let p = entry.path();
            if p.is_file() {
                let name = entry.file_name();
                fs::copy(&p, dest_dir.join(name))?;
            }
        }
        return Ok(());
    }

    let ext = src_path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();

    if ext == "cue" {
        // Copy CUE file
        let cue_name = src_path.file_name().unwrap_or_default();
        fs::copy(src_path, dest_dir.join(cue_name))?;

        // Also copy referenced track files
        let parent = src_path.parent().unwrap_or_else(|| Path::new("."));
        if let Ok(content) = fs::read_to_string(src_path) {
            let mut track_count = 0;
            for line in content.lines() {
                let trimmed = line.trim();
                if trimmed.starts_with("FILE") {
                    let filename = if let Some(start) = trimmed.find('"') {
                        trimmed[start + 1..].find('"').map(|end| &trimmed[start + 1..start + 1 + end])
                    } else {
                        let parts: Vec<&str> = trimmed.split_whitespace().collect();
                        if parts.len() >= 2 { Some(parts[1]) } else { None }
                    };

                    if let Some(track_file) = filename {
                        let track_src = parent.join(track_file);
                        if track_src.exists() {
                            track_count += 1;
                            println!("  📥 Empaquetant pista #{:02}: {}", track_count, track_file);
                            fs::copy(&track_src, dest_dir.join(track_file))?;
                        } else {
                            println!("  ⚠️ Atenció: Pista no trobada a: {}", track_src.display());
                        }
                    }
                }
            }
        }
    } else {
        let file_name = src_path.file_name().unwrap_or_default();
        println!("  📥 Copiant fitxer del disc: {}", file_name.to_string_lossy());
        fs::copy(src_path, dest_dir.join(file_name))?;
    }

    Ok(())
}

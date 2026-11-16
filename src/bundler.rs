use crate::icns::IcnsBuilder;
use crate::parser::SaturnGameInfo;
use crate::scraper::GameArtScraper;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppBundleOptions {
    pub internal_resolution: u32,   // 1 = Native 240p/480p, 2 = 2x, 4 = 4x, 8 = 8x Retina HD
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

        // 3. Generate AppIcon.icns & save authentic cover art
        let (icns_bytes, raw_cover_bytes): (Vec<u8>, Option<Vec<u8>>) = if let Some(ref icon_path) = options.icon_png_path {
            if icon_path.exists() {
                let png = fs::read(icon_path)?;
                let icns = IcnsBuilder::from_image_bytes(&png)
                    .unwrap_or_else(|_| IcnsBuilder::from_png(&png).unwrap_or_default());
                (icns, Some(png))
            } else {
                let fallback = IcnsBuilder::fallback_icon_for_game(&info.title, &info.product_id);
                (fallback, None)
            }
        } else {
            // Automatically search and download official box art online
            if let Some(scraped_png) = GameArtScraper::fetch_boxart(&info.title, &info.product_id, &info.regions) {
                let icns = IcnsBuilder::from_image_bytes(&scraped_png)
                    .unwrap_or_else(|_| IcnsBuilder::from_png(&scraped_png).unwrap_or_default());
                (icns, Some(scraped_png))
            } else {
                let fallback = IcnsBuilder::fallback_icon_for_game(&info.title, &info.product_id);
                (fallback, None)
            }
        };

        fs::write(resources_dir.join("AppIcon.icns"), &icns_bytes)?;
        if let Some(ref cover) = raw_cover_bytes {
            let _ = fs::write(resources_dir.join("Cover.png"), cover);
        }

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

        // 6. Embed native Apple Silicon runner and cores
        let bin_dest = resources_dir.join("bin");
        let cores_dest = resources_dir.join("cores");
        fs::create_dir_all(&bin_dest)?;
        fs::create_dir_all(&cores_dest)?;

        let direct_bin = macos_dir.join(&app_name);
        let launcher_path = macos_dir.join("Launcher");
        let launcher_script = generate_launcher_script(&app_name, info, options);

        if let Some(runner_src) = find_runner_binary() {
            // Direct native Cocoa Mach-O binary in Contents/MacOS/<app_name>
            fs::copy(&runner_src, &direct_bin)?;
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                fs::set_permissions(&direct_bin, fs::Permissions::from_mode(0o755))?;
            }

            // Also keep Resources/bin/saturn_runner for command line tools
            let target_runner = bin_dest.join("saturn_runner");
            fs::copy(&runner_src, &target_runner)?;
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                fs::set_permissions(&target_runner, fs::Permissions::from_mode(0o755))?;
            }
            println!("  ⚡ S'ha integrat el motor autònom natiu a Contents/MacOS/{}", app_name);
        } else {
            // Fallback: Write launcher script as primary binary if runner Mach-O is not compiled
            fs::write(&direct_bin, &launcher_script)?;
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                fs::set_permissions(&direct_bin, fs::Permissions::from_mode(0o755))?;
            }
            println!("  ⚠️ S'ha generat Launcher a Contents/MacOS/{}", app_name);
        }

        // Always write Launcher script
        fs::write(&launcher_path, launcher_script)?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(&launcher_path, fs::Permissions::from_mode(0o755))?;
        }

        // Copy cores
        if let Some(cores_src) = find_cores_dir() {
            if let Ok(entries) = fs::read_dir(&cores_src) {
                for entry in entries.flatten() {
                    let p = entry.path();
                    if p.is_file() {
                        let name = entry.file_name();
                        let target_dylib = cores_dest.join(&name);
                        fs::copy(&p, &target_dylib)?;
                        #[cfg(unix)]
                        {
                            let _ = std::process::Command::new("codesign")
                                .args(["--force", "--sign", "-", target_dylib.to_str().unwrap_or("")])
                                .status();
                        }
                        println!("  🎮 S'ha integrat el nucli de Saturn: {}", name.to_string_lossy());
                    }
                }
            }
        }

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            // Ensure all binaries inside MacOS directory are executable
            if let Ok(entries) = fs::read_dir(&macos_dir) {
                for entry in entries.flatten() {
                    let _ = fs::set_permissions(entry.path(), fs::Permissions::from_mode(0o755));
                }
            }

            // 1. Remove quarantine attributes so Gatekeeper doesn't show "está dañada o incompleta"
            let _ = std::process::Command::new("xattr")
                .args(["-cr", bundle_root.to_str().unwrap_or("")])
                .status();

            // 2. Deep sign bundle ad-hoc for Apple Silicon (ARM64 requirement)
            let _ = std::process::Command::new("codesign")
                .args(["--force", "--deep", "--sign", "-", bundle_root.to_str().unwrap_or("")])
                .status();
        }

        Ok(bundle_root)
    }
}

fn find_runner_binary() -> Option<PathBuf> {
    let mut candidates = Vec::new();

    // 1. Check relative to current saturnmac executable
    if let Ok(exe_path) = std::env::current_exe() {
        if let Some(exe_dir) = exe_path.parent() {
            candidates.push(exe_dir.join("saturn_runner"));
            candidates.push(exe_dir.join("../../../runner/bin/saturn_runner"));
            candidates.push(exe_dir.join("../../Resources/bin/saturn_runner"));
            candidates.push(exe_dir.join("../Resources/bin/saturn_runner"));
        }
    }

    // 2. Check relative to current working directory
    candidates.push(PathBuf::from("runner/bin/saturn_runner"));
    candidates.push(PathBuf::from("../runner/bin/saturn_runner"));
    candidates.push(PathBuf::from("dist/SaturnMac.app/Contents/Resources/bin/saturn_runner"));

    // 3. Check user home directory paths
    if let Ok(home) = std::env::var("HOME") {
        candidates.push(PathBuf::from(&home).join("Documents/SaturnMac/runner/bin/saturn_runner"));
        candidates.push(PathBuf::from(&home).join("Documents/SaturnMac/dist/SaturnMac.app/Contents/Resources/bin/saturn_runner"));
        candidates.push(PathBuf::from(&home).join("Applications/SaturnMac.app/Contents/Resources/bin/saturn_runner"));
    }
    candidates.push(PathBuf::from("/Applications/SaturnMac.app/Contents/Resources/bin/saturn_runner"));

    for c in candidates {
        if c.exists() && c.is_file() {
            return Some(c);
        }
    }
    None
}

fn find_cores_dir() -> Option<PathBuf> {
    let mut candidates = Vec::new();

    if let Ok(exe_path) = std::env::current_exe() {
        if let Some(exe_dir) = exe_path.parent() {
            candidates.push(exe_dir.join("cores"));
            candidates.push(exe_dir.join("../cores"));
            candidates.push(exe_dir.join("../../Resources/cores"));
            candidates.push(exe_dir.join("../Resources/cores"));
            candidates.push(exe_dir.join("../../../runner/cores"));
        }
    }

    candidates.push(PathBuf::from("runner/cores"));
    candidates.push(PathBuf::from("../runner/cores"));
    candidates.push(PathBuf::from("dist/SaturnMac.app/Contents/Resources/cores"));

    if let Ok(home) = std::env::var("HOME") {
        candidates.push(PathBuf::from(&home).join("Documents/SaturnMac/runner/cores"));
        candidates.push(PathBuf::from(&home).join("Documents/SaturnMac/dist/SaturnMac.app/Contents/Resources/cores"));
        candidates.push(PathBuf::from(&home).join("Applications/SaturnMac.app/Contents/Resources/cores"));
    }
    candidates.push(PathBuf::from("/Applications/SaturnMac.app/Contents/Resources/cores"));

    for c in candidates {
        if c.exists() && c.is_dir() {
            return Some(c);
        }
    }
    None
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
    <string>{app_name}</string>
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

fn generate_launcher_script(app_name: &str, info: &SaturnGameInfo, options: &AppBundleOptions) -> String {
    let region_flag = if info.region_codes.contains('J') {
        "jp"
    } else if info.region_codes.contains('E') {
        "eu"
    } else {
        "na"
    };

    let resolution = options.internal_resolution;

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
echo " Graphics: {resolution}x Retina Scaling + Metal Pipeline"
echo " Saves: $SAVES_DIR"
echo "=========================================="

# Locate primary game image (.cue, .chd, .iso, .bin)
ROM_TARGET=$(find "$GAME_DIR" -maxdepth 1 -iname "*.cue" | head -n 1)
if [ -z "$ROM_TARGET" ]; then
    ROM_TARGET=$(find "$GAME_DIR" -maxdepth 1 -iname "*.chd" | head -n 1)
fi
if [ -z "$ROM_TARGET" ]; then
    ROM_TARGET=$(find "$GAME_DIR" -maxdepth 1 \( -iname "*.iso" -o -iname "*.bin" \) | head -n 1)
fi

if [ -z "$ROM_TARGET" ]; then
    osascript -e 'display alert "SaturnMac Error" message "Game ROM files not found inside application bundle."'
    exit 1
fi

# Standalone native runner
RUNNER="$RESOURCES/bin/saturn_runner"
CORE="$RESOURCES/cores/yabause_libretro.dylib"

if [ ! -f "$CORE" ]; then
    CORE="$RESOURCES/cores/yabasanshiro_libretro.dylib"
fi

if [ ! -f "$CORE" ]; then
    CORE=$(find "$RESOURCES/cores" -name "*_libretro.dylib" 2>/dev/null | head -n 1)
fi

LOG_FILE="$SAVES_DIR/last_run.log"

if [ -x "$RUNNER" ]; then
    echo "Launching: $RUNNER --rom $ROM_TARGET --core $CORE" > "$LOG_FILE"
    "$RUNNER" --rom "$ROM_TARGET" --core "$CORE" --title "{title}" --resolution {resolution} >> "$LOG_FILE" 2>&1
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        ERR_MSG=$(tail -n 8 "$LOG_FILE" | tr '\n' ' ' | sed 's/"/\\"/g')
        osascript -e "display alert \"SaturnMac Error (Codi $EXIT_CODE)\" message \"Error iniciant {app_name}:\n\n$ERR_MSG\n\nFitxer de registre: $LOG_FILE\""
    fi
else
    osascript -e 'display alert "SaturnMac: Motor natiu pendent d\x27activar" message "Per fer que {app_name} funcioni en la seva pròpia finestra independent sense obrir OpenEmu, executa al terminal del teu Mac:\n\ncargo run -- setup-runner\n\ni torna a generar l\x27aplicació."'
fi
"#,
        app_name = app_name,
        title = info.title,
        product_id = info.product_id.trim(),
        region_flag = region_flag,
        resolution = resolution
    )
}

fn convert_audio_to_wav(src: &Path, dest: &Path) -> bool {
    // 1. Native macOS afconvert: 16-bit Linear PCM Little-Endian 44.1kHz Stereo
    if let Ok(status) = std::process::Command::new("afconvert")
        .args(["-f", "WAVE", "-d", "LEI16@44100"])
        .arg(src)
        .arg(dest)
        .status()
    {
        if status.success() && dest.exists() {
            return true;
        }
    }

    // 2. Fallback to ffmpeg if available
    if let Ok(output) = std::process::Command::new("ffmpeg")
        .args(["-y", "-i"])
        .arg(src)
        .args(["-ar", "44100", "-ac", "2", "-c:a", "pcm_s16le"])
        .arg(dest)
        .output()
    {
        if output.status.success() && dest.exists() {
            return true;
        }
    }

    false
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
        let cue_name = src_path.file_name().unwrap_or_default();
        let parent = src_path.parent().unwrap_or_else(|| Path::new("."));

        if let Ok(content) = fs::read_to_string(src_path) {
            let mut track_count = 0;
            let mut new_cue_lines: Vec<String> = Vec::new();

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
                        let resolved_track_path = crate::parser::resolve_cue_track(src_path, track_file);
                        if let Some(ref track_src) = resolved_track_path {
                            track_count += 1;
                            let actual_filename = track_src
                                .file_name()
                                .unwrap_or_default()
                                .to_string_lossy()
                                .to_string();
                            let track_ext = track_src
                                .extension()
                                .and_then(|e| e.to_str())
                                .unwrap_or("")
                                .to_lowercase();

                            if matches!(track_ext.as_str(), "mp3" | "m4a" | "ogg" | "flac" | "aac") {
                                let stem = track_src.file_stem().and_then(|s| s.to_str()).unwrap_or("track");
                                let wav_name = format!("{}.wav", stem);
                                let wav_dest = dest_dir.join(&wav_name);

                                println!("  🎵 Convertint pista d'àudio CD-DA a PCM WAV per a so natiu clar: {} -> {}", track_file, wav_name);
                                if convert_audio_to_wav(track_src, &wav_dest) {
                                    new_cue_lines.push(format!("FILE \"{}\" WAVE", wav_name));
                                    continue;
                                } else {
                                    println!("  ⚠️ No s'ha pogut convertir a WAV, copiant fitxer original: {}", actual_filename);
                                    fs::copy(track_src, dest_dir.join(&actual_filename))?;
                                    new_cue_lines.push(format!("FILE \"{}\" BINARY", actual_filename));
                                    continue;
                                }
                            } else {
                                if track_file != actual_filename {
                                    println!("  ✨ Pista corregida automàticament al CUE: \"{}\" -> \"{}\"", track_file, actual_filename);
                                }
                                println!("  📥 Empaquetant pista #{:02}: {}", track_count, actual_filename);
                                fs::copy(track_src, dest_dir.join(&actual_filename))?;

                                let file_type = if trimmed.ends_with("BINARY") {
                                    "BINARY"
                                } else if trimmed.ends_with("MOTOROLA") {
                                    "MOTOROLA"
                                } else {
                                    "BINARY"
                                };
                                new_cue_lines.push(format!("FILE \"{}\" {}", actual_filename, file_type));
                                continue;
                            }
                        } else {
                            println!("  ⚠️ Atenció: Pista no trobada a: {}", parent.join(track_file).display());
                        }
                    }
                    new_cue_lines.push(line.to_string());
                } else {
                    new_cue_lines.push(line.to_string());
                }
            }
            fs::write(dest_dir.join(cue_name), new_cue_lines.join("\n"))?;
        } else {
            fs::copy(src_path, dest_dir.join(cue_name))?;
        }
    } else {
        let file_name = src_path.file_name().unwrap_or_default();
        println!("  📥 Copiant fitxer del disc: {}", file_name.to_string_lossy());
        fs::copy(src_path, dest_dir.join(file_name))?;
    }

    Ok(())
}

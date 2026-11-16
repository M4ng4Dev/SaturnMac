use anyhow::{Context, Result};
use crate::icns::IcnsBuilder;
use crate::parser::SaturnGameInfo;
use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use zip::write::SimpleFileOptions;
use zip::ZipWriter;

pub struct IosReleaseBuilder;

impl IosReleaseBuilder {
    /// Generate a standalone universal iOS & iPadOS .ipa release package.
    pub fn create_ipa<P: AsRef<Path>, O: AsRef<Path>>(
        mac_app_bundle: P,
        info: &SaturnGameInfo,
        output_dir: O,
        icon_bytes: Option<&[u8]>,
    ) -> Result<PathBuf> {
        let mac_app_bundle = mac_app_bundle.as_ref();
        let output_dir = output_dir.as_ref();

        let clean_title = sanitize_filename(&info.title);
        let app_title = if clean_title.is_empty() {
            format!("Saturn_{}", info.product_id.replace(['/', '\\', ' '], "_"))
        } else {
            clean_title
        };

        let temp_dir = std::env::temp_dir().join(format!("saturn_ipa_{}", std::process::id()));
        let payload_dir = temp_dir.join("Payload");
        let app_dir = payload_dir.join(format!("{}.app", app_title));

        if temp_dir.exists() {
            let _ = fs::remove_dir_all(&temp_dir);
        }
        fs::create_dir_all(&app_dir)?;

        println!("📱 Construint paquet universal per a iPhone i iPad (iOS/iPadOS .ipa)...");

        // 1. Generate universal iOS Info.plist (UIDeviceFamily 1 = iPhone, 2 = iPad)
        let bundle_id = format!(
            "com.saturnmac.{}",
            info.product_id.to_lowercase().replace(['-', ' ', '_', '/'], "")
        );
        let plist_content = generate_ios_info_plist(&app_title, &bundle_id, &info.version);
        fs::write(app_dir.join("Info.plist"), plist_content)?;
        fs::write(app_dir.join("PkgInfo"), "APPL????")?;

        // 2. Generate iOS / iPadOS Icon files
        if let Some(art) = icon_bytes {
            let _ = IcnsBuilder::export_ios_icons(art, &app_dir);
        } else {
            let default_icon = IcnsBuilder::fallback_icon_for_game(&info.title, &info.product_id);
            let _ = IcnsBuilder::export_ios_icons(&default_icon, &app_dir);
        }

        // 3. Copy Game ROM, Config and Cores from the macOS bundle Resources
        let mac_resources = mac_app_bundle.join("Contents").join("Resources");
        let game_src = mac_resources.join("Game");
        if game_src.exists() {
            copy_dir_recursive(&game_src, &app_dir.join("Game"))?;
        }

        let config_src = mac_resources.join("Config");
        if config_src.exists() {
            copy_dir_recursive(&config_src, &app_dir.join("Config"))?;
        }

        let cores_src = mac_resources.join("cores");
        if cores_src.exists() {
            copy_dir_recursive(&cores_src, &app_dir.join("cores"))?;
        }

        let bin_src = mac_resources.join("bin");
        if bin_src.exists() {
            copy_dir_recursive(&bin_src, &app_dir.join("bin"))?;
        }

        // 4. Copy Launcher executable as the main iOS binary stub
        let mac_launcher = mac_app_bundle.join("Contents").join("MacOS").join("Launcher");
        if mac_launcher.exists() {
            let target_bin = app_dir.join("Launcher");
            fs::copy(&mac_launcher, &target_bin)?;
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let _ = fs::set_permissions(&target_bin, fs::Permissions::from_mode(0o755));
            }
        }

        // 5. Package into .ipa (zip of Payload/)
        fs::create_dir_all(output_dir)?;
        let ipa_path = output_dir.join(format!("{} (iOS-iPadOS).ipa", app_title));
        zip_directory(&temp_dir, &ipa_path)?;

        // Cleanup temp directory
        let _ = fs::remove_dir_all(&temp_dir);

        println!("  ✅ Paquet universal iOS / iPadOS creat amb èxit!");
        println!("     Arxiu: {}", ipa_path.display());
        println!("     Dispositius compatibles: iPhone (UIDeviceFamily 1) i iPad (UIDeviceFamily 2)");
        println!("     Instal·lació: Sideload directe mitjançant AltStore, SideStore, TrollStore o Xcode.");

        Ok(ipa_path)
    }
}

fn sanitize_filename(name: &str) -> String {
    name.chars()
        .filter(|c| c.is_alphanumeric() || *c == ' ' || *c == '-' || *c == '_')
        .collect::<String>()
        .trim()
        .to_string()
}

fn generate_ios_info_plist(app_name: &str, bundle_id: &str, version: &str) -> String {
    format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Launcher</string>
    <key>CFBundleIdentifier</key>
    <string>{bundle_id}</string>
    <key>CFBundleName</key>
    <string>{app_name}</string>
    <key>CFBundleDisplayName</key>
    <string>{app_name}</string>
    <key>CFBundleVersion</key>
    <string>{version}</string>
    <key>CFBundleShortVersionString</key>
    <string>{version}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>MinimumOSVersion</key>
    <string>14.0</string>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
        <integer>2</integer>
    </array>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
        <string>metal</string>
    </array>
    <key>UIRequiresFullScreen</key>
    <true/>
    <key>UIStatusBarHidden</key>
    <true/>
    <key>UIViewControllerBasedStatusBarAppearance</key>
    <false/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
    </array>
    <key>CFBundleIcons</key>
    <dict>
        <key>CFBundlePrimaryIcon</key>
        <dict>
            <key>CFBundleIconFiles</key>
            <array>
                <string>AppIcon60x60</string>
                <string>AppIcon76x76</string>
                <string>AppIcon83.5x83.5</string>
            </array>
            <key>CFBundleIconName</key>
            <string>AppIcon</string>
        </dict>
    </dict>
    <key>CFBundleIcons~ipad</key>
    <dict>
        <key>CFBundlePrimaryIcon</key>
        <dict>
            <key>CFBundleIconFiles</key>
            <array>
                <string>AppIcon76x76</string>
                <string>AppIcon83.5x83.5</string>
            </array>
            <key>CFBundleIconName</key>
            <string>AppIcon</string>
        </dict>
    </dict>
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
        <dict>
            <key>ProfileName</key>
            <string>DirectionalGamepad</string>
        </dict>
    </array>
    <key>GCSupportsControllerUserInteraction</key>
    <true/>
</dict>
</plist>
"#
    )
}

fn copy_dir_recursive(src: &Path, dst: &Path) -> Result<()> {
    fs::create_dir_all(dst)?;
    for entry in fs::read_dir(src)? {
        let entry = entry?;
        let ty = entry.file_type()?;
        let path = entry.path();
        let target = dst.join(entry.file_name());
        if ty.is_dir() {
            copy_dir_recursive(&path, &target)?;
        } else {
            fs::copy(&path, &target)?;
        }
    }
    Ok(())
}

fn zip_directory(src_dir: &Path, output_zip: &Path) -> Result<()> {
    let file = File::create(output_zip)?;
    let mut zip = ZipWriter::new(file);
    let options = SimpleFileOptions::default()
        .compression_method(zip::CompressionMethod::Deflated)
        .unix_permissions(0o755);

    let prefix = src_dir;
    add_dir_to_zip(&mut zip, prefix, src_dir, options)?;
    zip.finish()?;
    Ok(())
}

fn add_dir_to_zip<W: Write + std::io::Seek>(
    zip: &mut ZipWriter<W>,
    base_dir: &Path,
    current_dir: &Path,
    options: SimpleFileOptions,
) -> Result<()> {
    for entry in fs::read_dir(current_dir)? {
        let entry = entry?;
        let path = entry.path();
        let relative = path.strip_prefix(base_dir)?.to_str().context("Path not UTF-8")?;

        if path.is_dir() {
            let dir_name = format!("{}/", relative.replace('\\', "/"));
            zip.add_directory(dir_name, options)?;
            add_dir_to_zip(zip, base_dir, &path, options)?;
        } else {
            let file_name = relative.replace('\\', "/");
            zip.start_file(file_name, options)?;
            let mut f = File::open(&path)?;
            let mut buf = Vec::new();
            f.read_to_end(&mut buf)?;
            zip.write_all(&buf)?;
        }
    }
    Ok(())
}

use anyhow::{Context, Result};
use crate::bundler::{AppBundleOptions, AppBundler};
use crate::ios::IosReleaseBuilder;
use crate::parser::SaturnGameInfo;
use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::process::Command;
use zip::write::SimpleFileOptions;
use zip::ZipWriter;

pub struct ReleaseManager;

impl ReleaseManager {
    /// Generate all platform releases:
    /// 1. macOS .app bundle
    /// 2. macOS .dmg disk image (or .zip)
    /// 3. Universal iOS & iPadOS .ipa package
    pub fn build_all_releases<P: AsRef<Path>, O: AsRef<Path>>(
        rom_path: P,
        info: &SaturnGameInfo,
        output_dir: O,
        options: &AppBundleOptions,
    ) -> Result<ReleaseArtifacts> {
        let rom_path = rom_path.as_ref();
        let output_dir = output_dir.as_ref();
        fs::create_dir_all(output_dir)?;

        println!("\n📦 ========================================================");
        println!("  GENERANT DISTRIBUCIÓ MULTIPLATAFORMA (Mac, iPhone, iPad)");
        println!("  Joc: \"{}\" ({})", info.title, info.product_id);
        println!("  Resolució interna: {}x", options.internal_resolution);
        println!("==========================================================\n");

        // 1. Build macOS .app
        println!("🖥️ [1/3] Construint aplicació nativa per a macOS (.app)...");
        let app_bundle = AppBundler::create_app_bundle(rom_path, info, output_dir, options)?;

        // Read cover art if saved during bundle creation
        let cover_path = app_bundle.join("Contents").join("Resources").join("Cover.png");
        let icon_bytes = if cover_path.exists() {
            fs::read(&cover_path).ok()
        } else {
            None
        };

        // 2. Build macOS DMG / Disk Image
        println!("💿 [2/3] Empaquetant imatge de disc per a macOS (.dmg)...");
        let dmg_path = Self::build_mac_dmg(&app_bundle, &info.title, output_dir)?;

        // 3. Build Universal iOS & iPadOS .ipa
        println!("📱 [3/3] Generant paquet universal per a iPhone i iPad (.ipa)...");
        let ipa_path = IosReleaseBuilder::create_ipa(
            &app_bundle,
            info,
            output_dir,
            icon_bytes.as_deref(),
        )?;

        println!("\n🎉 ========================================================");
        println!("  RELEASES GENERADES AMB ÈXIT!");
        println!("  🖥️ macOS App:   {}", app_bundle.display());
        println!("  💿 macOS DMG:   {}", dmg_path.display());
        println!("  📱 iOS / iPad:  {}", ipa_path.display());
        println!("==========================================================\n");

        Ok(ReleaseArtifacts {
            mac_app: app_bundle,
            mac_dmg: dmg_path,
            ios_ipa: ipa_path,
        })
    }

    /// Package the .app into a macOS .dmg (Apple Disk Image) or .zip fallback
    fn build_mac_dmg(app_bundle: &Path, title: &str, output_dir: &Path) -> Result<PathBuf> {
        let clean_title = title
            .chars()
            .filter(|c| c.is_alphanumeric() || *c == ' ' || *c == '-' || *c == '_')
            .collect::<String>()
            .trim()
            .to_string();

        let dmg_path = output_dir.join(format!("{} (macOS).dmg", clean_title));

        // Attempt native macOS hdiutil
        let hdiutil_result = Command::new("hdiutil")
            .args([
                "create",
                "-volname",
                &clean_title,
                "-srcfolder",
                app_bundle.to_str().unwrap_or(""),
                "-ov",
                "-format",
                "UDZO",
                dmg_path.to_str().unwrap_or(""),
            ])
            .status();

        if let Ok(status) = hdiutil_result {
            if status.success() && dmg_path.exists() {
                println!("  ✅ S'ha generat el fitxer DMG natiu de macOS: {}", dmg_path.display());
                return Ok(dmg_path);
            }
        }

        // Fallback: Create a zip release if hdiutil is not available (e.g. Linux build host)
        let zip_path = output_dir.join(format!("{} (macOS).zip", clean_title));
        println!("  📦 Creant paquet comprimit per a macOS: {}", zip_path.display());

        let file = File::create(&zip_path)?;
        let mut zip = ZipWriter::new(file);
        let options = SimpleFileOptions::default()
            .compression_method(zip::CompressionMethod::Deflated)
            .unix_permissions(0o755);

        let parent_dir = app_bundle.parent().unwrap_or(output_dir);
        add_dir_to_zip(&mut zip, parent_dir, app_bundle, options)?;
        zip.finish()?;

        Ok(zip_path)
    }
}

pub struct ReleaseArtifacts {
    pub mac_app: PathBuf,
    pub mac_dmg: PathBuf,
    pub ios_ipa: PathBuf,
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

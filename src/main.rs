mod archive;
mod bundler;
mod icns;
mod ios;
mod parser;
mod release;
mod scraper;

use anyhow::{Context, Result};
use archive::ArchiveExtractor;
use bundler::{AppBundleOptions, AppBundler};
use clap::{Parser, Subcommand};
use parser::SaturnDiscParser;
use release::ReleaseManager;
use std::fs::File;
use std::io::Write;
use std::path::{Path, PathBuf};

#[derive(Parser, Debug)]
#[command(
    name = "saturnmac",
    author = "carlosSP",
    version = "0.1.0",
    about = "Convert Sega Saturn game ROMs (BIN, CUE, ISO, CHD, ZIP) into standalone native macOS applications and iOS/iPadOS packages optimized for Apple Silicon."
)]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Launch the SaturnMac graphical studio application
    App,

    /// Launch the SaturnMac graphical studio application
    Gui,

    /// Inspect a Sega Saturn disc image and show header metadata
    Inspect {
        /// Path to .cue, .bin, .iso, or .zip file
        #[arg(value_name = "ROM_PATH")]
        path: PathBuf,

        /// Output format as JSON
        #[arg(short, long)]
        json: bool,
    },

    /// Package a Sega Saturn ROM into a standalone macOS .app bundle
    Bundle {
        /// Path to .cue, .bin, .iso, or .zip file
        #[arg(value_name = "ROM_PATH")]
        path: PathBuf,

        /// Output directory where the .app bundle will be saved
        #[arg(short, long, default_value = "./dist")]
        output: PathBuf,

        /// Optional path to a custom icon PNG or box art (auto-searched online if omitted)
        #[arg(short, long)]
        icon: Option<PathBuf>,

        /// Internal rendering resolution (1 = 240p native, 2 = 2x, 4 = 4x Retina, 8 = 8x Ultra HD)
        #[arg(short, long, default_value_t = 4)]
        resolution: u32,

        /// Enable Metal CRT phosphor shader
        #[arg(long)]
        crt: bool,

        /// Enable 16:9 anamorphic widescreen geometry mode
        #[arg(long)]
        widescreen: bool,

        /// Enable adaptive de-dither filter for mesh transparencies
        #[arg(long)]
        dedither: bool,

        /// Disable adaptive anti-aliasing / smoothing filter
        #[arg(long)]
        no_smoothing: bool,
    },

    /// Generate complete multiplatform releases for macOS (.app & .dmg) and universal iOS/iPadOS (.ipa)
    Release {
        /// Path to .cue, .bin, .iso, or .zip file
        #[arg(value_name = "ROM_PATH")]
        path: PathBuf,

        /// Output directory where release packages will be saved
        #[arg(short, long, default_value = "./dist/releases")]
        output: PathBuf,

        /// Optional path to a custom icon PNG or box art (auto-searched online if omitted)
        #[arg(short, long)]
        icon: Option<PathBuf>,

        /// Internal rendering resolution (1 = 240p native, 2 = 2x, 4 = 4x Retina, 8 = 8x Ultra HD)
        #[arg(short, long, default_value_t = 4)]
        resolution: u32,

        /// Enable Metal CRT phosphor shader
        #[arg(long)]
        crt: bool,

        /// Enable 16:9 anamorphic widescreen geometry mode
        #[arg(long)]
        widescreen: bool,

        /// Enable adaptive de-dither filter for mesh transparencies
        #[arg(long)]
        dedither: bool,

        /// Disable adaptive anti-aliasing / smoothing filter
        #[arg(long)]
        no_smoothing: bool,
    },

    /// Generate a synthetic Sega Saturn disc image for testing
    Mock {
        /// Output path for the mock disc (e.g. tests/sample.bin)
        #[arg(value_name = "OUTPUT_PATH", default_value = "mock_saturn.bin")]
        output: PathBuf,

        /// Custom game title
        #[arg(long, default_value = "NIGHTS INTO DREAMS...")]
        title: String,

        /// Product number
        #[arg(long, default_value = "MK-81005")]
        product: String,

        /// Region code (J, U, E, etc.)
        #[arg(long, default_value = "U")]
        region: String,
    },

    /// Search for matching box arts from the 2,294 Sega Saturn database
    SearchArt {
        /// Search query (game title)
        query: String,

        /// Limit number of results (default: 10)
        #[arg(short, long, default_value_t = 10)]
        limit: usize,

        /// Output format as JSON
        #[arg(short, long)]
        json: bool,
    },

    /// Build or download the native standalone Apple Silicon runner and core
    SetupRunner,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    let cmd = cli.command.unwrap_or(Commands::App);

    match cmd {
        Commands::App | Commands::Gui => {
            let app_path = Path::new("dist/SaturnMac.app");
            if !app_path.exists() {
                println!("⚙️ No s'ha trobat dist/SaturnMac.app. Compilant l'entorn gràfic...");
                setup_runner_and_app()?;
            }
            println!("🚀 Obrint SaturnMac Studio en entorn gràfic...");
            #[cfg(target_os = "macos")]
            {
                let _ = std::process::Command::new("open")
                    .arg(app_path)
                    .status();
            }
            #[cfg(not(target_os = "macos"))]
            {
                println!("ℹ️ SaturnMac.app és l'aplicació nativa de macOS ubicada a: {}", app_path.display());
            }
        }

        Commands::Inspect { path, json } => {
            let is_archive = ArchiveExtractor::is_archive(&path);
            let (target_rom, temp_cleanup) = if is_archive {
                println!("📦 S'ha detectat un arxiu comprimit: {}", path.display());
                let temp_dir = ArchiveExtractor::extract_archive(&path)?;
                let primary = ArchiveExtractor::find_primary_rom(&temp_dir)?;
                (primary, Some(temp_dir))
            } else {
                (path.clone(), None)
            };

            println!("🔍 Inspecting Sega Saturn disc image: {}", target_rom.display());
            let info = SaturnDiscParser::parse(&target_rom)
                .with_context(|| format!("Failed to parse Saturn disc at {}", target_rom.display()))?;

            if let Some(ref dir) = temp_cleanup {
                let _ = std::fs::remove_dir_all(dir);
            }

            if json {
                let out = serde_json::to_string_pretty(&info)?;
                println!("{}", out);
            } else {
                println!("\n================ Sega Saturn Header ================");
                println!("  Title:        {}", info.title);
                println!("  Product ID:   {}", info.product_id);
                println!("  Maker:        {}", info.maker_id);
                println!("  Hardware:     {}", info.hardware_id);
                println!("  Version:      {}", info.version);
                println!("  Release Date: {}", info.release_date);
                println!("  Disc Info:    {}", info.disc_info);
                println!("  Sector Mode:  {}", info.sector_mode);
                println!("  Regions:      {}", info.regions.join(", "));
                println!("  Peripherals:  {}", info.peripherals.join(", "));
                println!("  Tracks:       {}", info.tracks.len());
                for track in &info.tracks {
                    println!("    Track #{:02}: {} ({})", track.number, track.track_type, track.filename);
                }
                println!("====================================================\n");
            }
        }

        Commands::Bundle {
            path,
            output,
            icon,
            resolution,
            crt,
            widescreen,
            dedither,
            no_smoothing,
        } => {
            let is_archive = ArchiveExtractor::is_archive(&path);
            let (target_rom, temp_cleanup) = if is_archive {
                println!("📦 S'ha detectat un arxiu comprimit amb múltiples fitxers: {}", path.display());
                let temp_dir = ArchiveExtractor::extract_archive(&path)?;
                let primary = ArchiveExtractor::find_primary_rom(&temp_dir)?;
                println!("  🎯 S'ha localitzat la imatge principal del joc: {}", primary.file_name().unwrap_or_default().to_string_lossy());
                (primary, Some(temp_dir))
            } else {
                (path.clone(), None)
            };

            println!("📦 Reading disc info from: {}", target_rom.display());
            let info = SaturnDiscParser::parse(&target_rom)?;
            println!("✨ Detected Game: \"{}\" ({})", info.title, info.product_id);

            let options = AppBundleOptions {
                internal_resolution: resolution,
                metal_rendering: true,
                promotion_120hz: true,
                widescreen_anamorphic: widescreen,
                crt_shader: crt,
                dedither,
                smoothing: !no_smoothing,
                icon_png_path: icon,
            };

            std::fs::create_dir_all(&output)?;
            let bundle_path = AppBundler::create_app_bundle(&target_rom, &info, &output, &options)?;

            if let Some(ref dir) = temp_cleanup {
                let _ = std::fs::remove_dir_all(dir);
            }

            println!("\n🚀 macOS Application Bundle Created Successfully!");
            println!("  Path: {}", bundle_path.display());
            println!("  Bundle ID: com.saturnmac.{}", info.product_id.to_lowercase().replace(['-', ' ', '_', '/'], ""));
            println!("  Optimizations: Apple Silicon ARM64, Metal Pipeline, ProMotion 120Hz, GameController API");
        }

        Commands::Release {
            path,
            output,
            icon,
            resolution,
            crt,
            widescreen,
            dedither,
            no_smoothing,
        } => {
            let is_archive = ArchiveExtractor::is_archive(&path);
            let (target_rom, temp_cleanup) = if is_archive {
                println!("📦 S'ha detectat un arxiu comprimit: {}", path.display());
                let temp_dir = ArchiveExtractor::extract_archive(&path)?;
                let primary = ArchiveExtractor::find_primary_rom(&temp_dir)?;
                println!("  🎯 S'ha localitzat la imatge principal del joc: {}", primary.file_name().unwrap_or_default().to_string_lossy());
                (primary, Some(temp_dir))
            } else {
                (path.clone(), None)
            };

            println!("📦 Reading disc info from: {}", target_rom.display());
            let info = SaturnDiscParser::parse(&target_rom)?;
            println!("✨ Detected Game: \"{}\" ({})", info.title, info.product_id);

            let options = AppBundleOptions {
                internal_resolution: resolution,
                metal_rendering: true,
                promotion_120hz: true,
                widescreen_anamorphic: widescreen,
                crt_shader: crt,
                dedither,
                smoothing: !no_smoothing,
                icon_png_path: icon,
            };

            let artifacts = ReleaseManager::build_all_releases(&target_rom, &info, &output, &options)?;

            if let Some(ref dir) = temp_cleanup {
                let _ = std::fs::remove_dir_all(dir);
            }

            println!("🏁 Release completa finalitzada.");
            println!("  - Mac App:  {}", artifacts.mac_app.display());
            println!("  - Mac DMG:  {}", artifacts.mac_dmg.display());
            println!("  - iOS/iPad: {}", artifacts.ios_ipa.display());
        }

        Commands::Mock {
            output,
            title,
            product,
            region,
        } => {
            println!("🛠️ Generating synthetic Sega Saturn disc image: {}", output.display());
            generate_mock_disc(&output, &title, &product, &region)?;
            println!("✅ Mock Saturn disc image created at {}", output.display());
        }

        Commands::SearchArt { query, limit, json } => {
            let matches = scraper::GameArtScraper::find_similar_boxarts(&query, &[], limit);
            if json {
                let json_list: Vec<serde_json::Value> = matches
                    .iter()
                    .map(|filename| {
                        let encoded = scraper::urlencoding_simple(filename);
                        serde_json::json!({
                            "filename": filename,
                            "url": format!("https://raw.githubusercontent.com/libretro-thumbnails/Sega_-_Saturn/master/Named_Boxarts/{}", encoded)
                        })
                    })
                    .collect();
                println!("{}", serde_json::to_string_pretty(&json_list)?);
            } else {
                println!("🔎 S'han trobat {} caràtules similars per a \"{}\":", matches.len(), query);
                for (i, name) in matches.iter().enumerate() {
                    println!("  {}. {}", i + 1, name);
                }
            }
        }

        Commands::SetupRunner => {
            setup_runner_and_app()?;
        }
    }

    Ok(())
}

fn setup_runner_and_app() -> Result<()> {
    println!("⚙️ Configuració de SaturnMac Studio per a Apple Silicon...");
    let runner_script = Path::new("runner/build_runner.sh");
    if !runner_script.exists() {
        anyhow::bail!("No s'ha trobat runner/build_runner.sh!");
    }
    let status = std::process::Command::new("bash")
        .arg(runner_script)
        .status()
        .context("Error executant build_runner.sh")?;
    if status.success() {
        // Embed official high-res Saturn icon and authentic BIOS
        let saturn_app_res = Path::new("dist/SaturnMac.app/Contents/Resources");
        if saturn_app_res.exists() {
            let icns_bytes = icns::IcnsBuilder::default_saturn_icon();
            let _ = std::fs::write(saturn_app_res.join("AppIcon.icns"), icns_bytes);

            let bios_src = Path::new("runner/bios");
            if bios_src.exists() {
                let dist_bios = saturn_app_res.join("bios");
                let _ = std::fs::create_dir_all(&dist_bios);
                if let Ok(entries) = std::fs::read_dir(bios_src) {
                    for entry in entries.flatten() {
                        let _ = std::fs::copy(entry.path(), dist_bios.join(entry.file_name()));
                    }
                }
            }
        }

        println!("\n🎉 SaturnMac.app està a punt a: dist/SaturnMac.app!");
        println!("  Pots obrir-la directament o moure-la a /Applications per portejar qualsevol joc de Saturn en entorn gràfic.");
    } else {
        anyhow::bail!("Ha fallat la compilació. Comprova la sortida del compilador.");
    }
    Ok(())
}

fn generate_mock_disc(output_path: &Path, title: &str, product: &str, region: &str) -> Result<()> {
    if let Some(parent) = output_path.parent() {
        if !parent.as_os_str().is_empty() {
            std::fs::create_dir_all(parent)?;
        }
    }

    // Create a 2352-byte RAW sector with Saturn IP.BIN
    let mut sector = vec![0u8; 2352 * 16]; // 16 sectors

    // Sync pattern for sector 0
    sector[0..12].copy_from_slice(&[0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00]);
    sector[12..15].copy_from_slice(&[0x00, 0x02, 0x00]); // 00:02:00
    sector[15] = 0x01; // Mode 1

    // IP.BIN starts at offset 16 (in raw 2352 sector)
    let ip = &mut sector[16..16 + 256];
    copy_str_to_slice("SEGA SEGASATURN ", &mut ip[0..16]);
    copy_str_to_slice("SEGA ENTERPRISES", &mut ip[16..32]);
    copy_str_to_slice(product, &mut ip[32..42]);
    copy_str_to_slice("V1.000", &mut ip[42..48]);
    copy_str_to_slice("19960715", &mut ip[48..56]);
    copy_str_to_slice("CD-1/1  ", &mut ip[56..64]);
    copy_str_to_slice(region, &mut ip[64..74]);
    copy_str_to_slice("J       ", &mut ip[74..80]);

    // Title at offset 96
    copy_str_to_slice(title, &mut ip[96..208]);

    let mut file = File::create(output_path)?;
    file.write_all(&sector)?;
    Ok(())
}

fn copy_str_to_slice(s: &str, slice: &mut [u8]) {
    slice.fill(b' ');
    let bytes = s.as_bytes();
    let len = bytes.len().min(slice.len());
    slice[..len].copy_from_slice(&bytes[..len]);
}

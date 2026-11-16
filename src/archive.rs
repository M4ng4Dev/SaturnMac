use anyhow::{bail, Context, Result};
use std::fs::{self, File};
use std::path::{Path, PathBuf};
use std::process::Command;

pub struct ArchiveExtractor;

#[allow(dead_code)]
pub type ZipExtractor = ArchiveExtractor;

impl ArchiveExtractor {
    /// Check whether a given path is a supported compressed archive
    pub fn is_archive(path: &Path) -> bool {
        let ext = path
            .extension()
            .and_then(|e| e.to_str())
            .unwrap_or("")
            .to_lowercase();
        matches!(
            ext.as_str(),
            "zip" | "rar" | "7z" | "tar" | "gz" | "tgz" | "bz2" | "xz"
        )
    }

    /// Extract an archive (.zip, .rar, .7z, .tar, etc.) into a temporary directory
    pub fn extract_archive(archive_path: &Path) -> Result<PathBuf> {
        let ext = archive_path
            .extension()
            .and_then(|e| e.to_str())
            .unwrap_or("")
            .to_lowercase();

        let stem = archive_path
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("saturn_game");
        let temp_dir = std::env::temp_dir().join(format!("saturnmac_{}_{}", stem, std::process::id()));
        fs::create_dir_all(&temp_dir)?;

        if ext == "zip" {
            Self::extract_zip_internal(archive_path, &temp_dir)?;
            return Ok(temp_dir);
        }

        // Try extracting using available CLI tools for RAR, 7Z, TAR, etc.
        if Self::extract_with_cli_tools(archive_path, &temp_dir)? {
            return Ok(temp_dir);
        }

        let _ = fs::remove_dir_all(&temp_dir);

        if ext == "rar" {
            bail!(
                "L'arxiu \"{}\" és un fitxer comprimit RAR (.rar).\n\
                 ℹ️ Per extreure'l automàticament des de SaturnMac cal tenir instal·lat 'unar' o '7z' al Mac.\n\
                 👉 Solució fàcil: Fes doble clic a \"{}\" al Finder (o fes servir The Unarchiver) per descomprimir-lo, i arrossega directament el fitxer resultant (.cue, .iso, .chd o .bin) a SaturnMac.",
                archive_path.display(),
                archive_path.file_name().unwrap_or_default().to_string_lossy()
            );
        } else if ext == "7z" {
            bail!(
                "L'arxiu \"{}\" és un fitxer comprimit 7-Zip (.7z).\n\
                 ℹ️ Per extreure'l cal tenir instal·lat 'unar' o '7z' ('brew install p7zip' o 'brew install unar').\n\
                 👉 Solució fàcil: Descomprimeix-lo al Finder o amb The Unarchiver i arrossega el fitxer de disc resultant (.cue, .iso, .chd o .bin) a SaturnMac.",
                archive_path.display()
            );
        } else {
            bail!("No s'ha pogut descomprimir el format d'arxiu .{} per a: {}", ext, archive_path.display());
        }
    }

    /// Backwards compatible alias for extract_zip
    #[allow(dead_code)]
    pub fn extract_zip(zip_path: &Path) -> Result<PathBuf> {
        Self::extract_archive(zip_path)
    }

    /// Internal zip extraction using pure Rust zip crate
    fn extract_zip_internal(zip_path: &Path, temp_dir: &Path) -> Result<()> {
        let file = File::open(zip_path)
            .with_context(|| format!("Failed to open ZIP file at: {}", zip_path.display()))?;
        let mut archive = zip::ZipArchive::new(file)
            .with_context(|| format!("Invalid ZIP archive format: {}", zip_path.display()))?;

        for i in 0..archive.len() {
            let mut file = archive.by_index(i)?;
            let outpath = match file.enclosed_name() {
                Some(path) => temp_dir.join(path),
                None => continue,
            };

            if file.is_dir() {
                fs::create_dir_all(&outpath)?;
            } else {
                if let Some(p) = outpath.parent() {
                    if !p.exists() {
                        fs::create_dir_all(p)?;
                    }
                }
                let mut outfile = File::create(&outpath)?;
                std::io::copy(&mut file, &mut outfile)?;
            }
        }

        Ok(())
    }

    /// Tries CLI extraction tools (unar, 7z, 7za, unrar, tar)
    fn extract_with_cli_tools(archive_path: &Path, dest_dir: &Path) -> Result<bool> {
        let dest_str = dest_dir.to_str().unwrap_or("");
        let archive_str = archive_path.to_str().unwrap_or("");
        let out_7z = format!("-o{}", dest_str);
        let dest_slash = format!("{}/", dest_str);

        let candidate_commands: [(&str, Vec<&str>); 13] = [
            // unar (The Unarchiver / Homebrew)
            ("unar", vec!["-quiet", "-D", "-o", dest_str, archive_str]),
            ("/Applications/The Unarchiver.app/Contents/SharedSupport/unar", vec!["-quiet", "-D", "-o", dest_str, archive_str]),
            ("/opt/homebrew/bin/unar", vec!["-quiet", "-D", "-o", dest_str, archive_str]),
            ("/usr/local/bin/unar", vec!["-quiet", "-D", "-o", dest_str, archive_str]),

            // 7z / 7za
            ("7z", vec!["x", "-y", &out_7z, archive_str]),
            ("/opt/homebrew/bin/7z", vec!["x", "-y", &out_7z, archive_str]),
            ("/usr/local/bin/7z", vec!["x", "-y", &out_7z, archive_str]),
            ("7za", vec!["x", "-y", &out_7z, archive_str]),

            // unrar
            ("unrar", vec!["x", "-y", archive_str, &dest_slash]),
            ("/opt/homebrew/bin/unrar", vec!["x", "-y", archive_str, &dest_slash]),
            ("/usr/local/bin/unrar", vec!["x", "-y", archive_str, &dest_slash]),

            // tar
            ("tar", vec!["-xf", archive_str, "-C", dest_str]),
            ("/usr/bin/tar", vec!["-xf", archive_str, "-C", dest_str]),
        ];

        for (cmd, args) in candidate_commands {
            if let Ok(status) = Command::new(cmd).args(&args).status() {
                if status.success() {
                    if let Ok(mut entries) = fs::read_dir(dest_dir) {
                        if entries.next().is_some() {
                            return Ok(true);
                        }
                    }
                }
            }
        }

        Ok(false)
    }

    /// Recursively search for primary Saturn ROM file (.cue, .chd, .iso, .bin)
    pub fn find_primary_rom(dir: &Path) -> Result<PathBuf> {
        let mut cue = None;
        let mut chd = None;
        let mut iso = None;
        let mut bin = None;

        fn visit_dirs(
            dir: &Path,
            cue: &mut Option<PathBuf>,
            chd: &mut Option<PathBuf>,
            iso: &mut Option<PathBuf>,
            bin: &mut Option<PathBuf>,
        ) {
            if let Ok(entries) = fs::read_dir(dir) {
                for entry in entries.flatten() {
                    let path = entry.path();
                    if path.is_dir() {
                        visit_dirs(&path, cue, chd, iso, bin);
                    } else if path.is_file() {
                        let ext = path
                            .extension()
                            .and_then(|e| e.to_str())
                            .unwrap_or("")
                            .to_lowercase();
                        match ext.as_str() {
                            "cue" if cue.is_none() => *cue = Some(path),
                            "chd" if chd.is_none() => *chd = Some(path),
                            "iso" if iso.is_none() => *iso = Some(path),
                            "bin" if bin.is_none() => *bin = Some(path),
                            _ => {}
                        }
                    }
                }
            }
        }

        visit_dirs(dir, &mut cue, &mut chd, &mut iso, &mut bin);

        if let Some(c) = cue {
            return Ok(c);
        }
        if let Some(ch) = chd {
            return Ok(ch);
        }
        if let Some(i) = iso {
            return Ok(i);
        }
        if let Some(b) = bin {
            return Ok(b);
        }

        bail!("No s'ha trobat cap fitxer de disc de Sega Saturn (.cue, .chd, .iso, .bin) dins de l'arxiu.")
    }
}

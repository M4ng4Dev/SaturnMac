use anyhow::{bail, Context, Result};
use std::fs::{self, File};
use std::path::{Path, PathBuf};

pub struct ZipExtractor;

impl ZipExtractor {
    /// Extract a zip file into a temporary directory
    pub fn extract_zip(zip_path: &Path) -> Result<PathBuf> {
        let file = File::open(zip_path)
            .with_context(|| format!("Failed to open ZIP file at: {}", zip_path.display()))?;
        let mut archive = zip::ZipArchive::new(file)
            .with_context(|| format!("Invalid ZIP archive format: {}", zip_path.display()))?;

        let stem = zip_path
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("saturn_game");
        let temp_dir = std::env::temp_dir().join(format!("saturnmac_{}_{}", stem, std::process::id()));
        fs::create_dir_all(&temp_dir)?;

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

        Ok(temp_dir)
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

        bail!("No s'ha trobat cap fitxer de disc de Sega Saturn (.cue, .chd, .iso, .bin) dins de l'arxiu ZIP.")
    }
}

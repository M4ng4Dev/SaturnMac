use anyhow::{bail, Context, Result};
use encoding_rs::SHIFT_JIS;
use serde::{Deserialize, Serialize};
use std::fs::{self, File};
use std::io::Read;
use std::path::{Path, PathBuf};

/// Detailed information extracted from a Sega Saturn disc image header.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SaturnGameInfo {
    pub hardware_id: String,
    pub maker_id: String,
    pub product_id: String,
    pub version: String,
    pub release_date: String,
    pub disc_info: String,
    pub region_codes: String,
    pub regions: Vec<String>,
    pub peripheral_codes: String,
    pub peripherals: Vec<String>,
    pub title: String,
    pub sector_mode: String,
    pub tracks: Vec<TrackInfo>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrackInfo {
    pub number: u32,
    pub track_type: String,
    pub filename: String,
}

pub struct SaturnDiscParser;

impl SaturnDiscParser {
    /// Inspect any Sega Saturn image file (.cue, .bin, .iso, .chd).
    pub fn parse<P: AsRef<Path>>(path: P) -> Result<SaturnGameInfo> {
        let path = path.as_ref();
        let ext = path
            .extension()
            .and_then(|e| e.to_str())
            .unwrap_or("")
            .to_lowercase();

        if crate::archive::ArchiveExtractor::is_archive(path) {
            let temp_dir = crate::archive::ArchiveExtractor::extract_archive(path)?;
            let primary = crate::archive::ArchiveExtractor::find_primary_rom(&temp_dir)?;
            let info = Self::parse(&primary);
            let _ = std::fs::remove_dir_all(&temp_dir);
            return info;
        }

        match ext.as_str() {
            "cue" => Self::parse_cue(path),
            "bin" | "iso" | "img" => Self::parse_binary_disc(path, None),
            _ => {
                // Try as raw binary disc anyway
                Self::parse_binary_disc(path, None)
            }
        }
    }

    /// Parse a CUE sheet, resolving Track 01 binary file.
    pub fn parse_cue(cue_path: &Path) -> Result<SaturnGameInfo> {
        let content = std::fs::read_to_string(cue_path)
            .with_context(|| format!("Failed to read CUE sheet: {}", cue_path.display()))?;

        let parent_dir = cue_path.parent().unwrap_or_else(|| Path::new("."));
        let mut tracks = Vec::new();
        let mut current_file: Option<String> = None;
        let mut first_data_track_path: Option<PathBuf> = None;
        let mut current_track_num = 0;

        for line in content.lines() {
            let line = line.trim();
            if line.starts_with("FILE") {
                // Example: FILE "Nights.bin" BINARY
                if let Some(start_quote) = line.find('"') {
                    if let Some(end_quote) = line[start_quote + 1..].find('"') {
                        let filename = &line[start_quote + 1..start_quote + 1 + end_quote];
                        current_file = Some(filename.to_string());
                    }
                } else {
                    let parts: Vec<&str> = line.split_whitespace().collect();
                    if parts.len() >= 2 {
                        current_file = Some(parts[1].to_string());
                    }
                }
            } else if line.starts_with("TRACK") {
                // Example: TRACK 01 MODE1/2352
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 3 {
                    current_track_num = parts[1].parse::<u32>().unwrap_or(current_track_num + 1);
                    let track_type = parts[2].to_string();
                    let filename = current_file.clone().unwrap_or_default();

                    tracks.push(TrackInfo {
                        number: current_track_num,
                        track_type: track_type.clone(),
                        filename: filename.clone(),
                    });

                    if first_data_track_path.is_none()
                        && (track_type.contains("MODE1")
                            || track_type.contains("MODE2")
                            || track_type.contains("AUDIO") == false)
                    {
                        if let Some(ref fname) = current_file {
                            if let Some(resolved) = resolve_cue_track(cue_path, fname) {
                                first_data_track_path = Some(resolved);
                            } else {
                                first_data_track_path = Some(parent_dir.join(fname));
                            }
                        }
                    }
                }
            }
        }

        let data_bin = match first_data_track_path {
            Some(p) if p.is_file() => p,
            Some(p) => {
                let fname = p.file_name().and_then(|n| n.to_str()).unwrap_or("");
                if let Some(resolved) = resolve_cue_track(cue_path, fname) {
                    println!("  ✨ Pista de dades localitzada automàticament: \"{}\" -> \"{}\"", fname, resolved.file_name().unwrap_or_default().to_string_lossy());
                    resolved
                } else if let Some(resolved) = resolve_cue_track(cue_path, "") {
                    println!("  ✨ Pista de dades alternativa localitzada: \"{}\"", resolved.file_name().unwrap_or_default().to_string_lossy());
                    resolved
                } else {
                    bail!(
                        "No s'ha pogut localitzar el fitxer de dades per a la pista 01 (\"{}\") indicat al CUE.\n\
                         Ruta esperada: {}\n\
                         Comprova que el fitxer .bin o .iso es troba a la mateixa carpeta.",
                        fname,
                        p.display()
                    );
                }
            }
            None => {
                // Fallback: look for a file with same base name and common extensions
                if let Some(resolved) = resolve_cue_track(cue_path, "") {
                    resolved
                } else {
                    bail!("Could not locate Track 01 data file referenced in CUE sheet");
                }
            }
        };

        Self::parse_binary_disc(&data_bin, Some(tracks))
    }

    /// Parse header from a raw BIN or ISO image.
    pub fn parse_binary_disc(path: &Path, known_tracks: Option<Vec<TrackInfo>>) -> Result<SaturnGameInfo> {
        let mut file = File::open(path)
            .with_context(|| format!("Unable to open disc file: {}", path.display()))?;

        // Read up to first 64KB (covers initial sectors and CD headers)
        let mut buffer = vec![0u8; 65536];
        let bytes_read = file.read(&mut buffer)?;
        if bytes_read < 256 {
            bail!("Disc file is too small to be a valid Sega Saturn image");
        }

        // Search for Saturn IP.BIN signature
        let magic = b"SEGA SEGASATURN";
        let mut header_offset: Option<usize> = None;
        let mut sector_mode = "ISO (2048 bytes)";

        // Check offset 0 (Mode 1 / 2048 bytes ISO format)
        if buffer.len() >= 15 && &buffer[0..15] == magic {
            header_offset = Some(0);
        } else if buffer.len() >= 32 && &buffer[16..31] == magic {
            // Raw 2352 bytes / sector with 16-byte sync+header
            header_offset = Some(16);
            sector_mode = "RAW (2352 bytes)";
        } else {
            // Search inside the first 32 sectors
            for i in (0..bytes_read.saturating_sub(16)).step_by(16) {
                if &buffer[i..i + 15] == magic {
                    header_offset = Some(i);
                    sector_mode = if i % 2352 == 16 {
                        "RAW (2352 bytes)"
                    } else {
                        "Custom/Offset LBA"
                    };
                    break;
                }
            }
        }

        let offset = match header_offset {
            Some(o) => o,
            None => bail!("File is not a valid Sega Saturn CD-ROM image (missing 'SEGA SEGASATURN' signature)"),
        };

        if buffer.len() < offset + 256 {
            bail!("Incomplete Saturn header in disc image");
        }

        let slice = &buffer[offset..offset + 256];

        let hardware_id = clean_ascii(&slice[0..16]);
        let maker_id = clean_ascii(&slice[16..32]);
        let product_id = clean_ascii(&slice[32..42]);
        let version = clean_ascii(&slice[42..48]);
        let release_date = clean_ascii(&slice[48..56]);
        let disc_info = clean_ascii(&slice[56..64]);
        let region_codes = clean_ascii(&slice[64..74]);
        let peripheral_codes = clean_ascii(&slice[74..80]);

        // Game title: bytes 96..208 (112 bytes)
        let title_bytes = &slice[96..208];
        let title = decode_title(title_bytes);

        let regions = decode_regions(&region_codes);
        let peripherals = decode_peripherals(&peripheral_codes);

        let tracks = known_tracks.unwrap_or_else(|| {
            vec![TrackInfo {
                number: 1,
                track_type: sector_mode.to_string(),
                filename: path.file_name().unwrap_or_default().to_string_lossy().to_string(),
            }]
        });

        Ok(SaturnGameInfo {
            hardware_id,
            maker_id,
            product_id,
            version,
            release_date,
            disc_info,
            region_codes,
            regions,
            peripheral_codes,
            peripherals,
            title,
            sector_mode: sector_mode.to_string(),
            tracks,
        })
    }
}

fn clean_ascii(bytes: &[u8]) -> String {
    String::from_utf8_lossy(bytes)
        .trim_matches(|c: char| c.is_whitespace() || c == '\0')
        .to_string()
}

fn decode_title(bytes: &[u8]) -> String {
    // Try Shift-JIS first as Saturn titles often contain Japanese or English Shift-JIS
    let (decoded, _, _) = SHIFT_JIS.decode(bytes);
    let title = decoded
        .trim_matches(|c: char| c.is_whitespace() || c == '\0')
        .to_string();
    if !title.is_empty() {
        return title;
    }
    String::from_utf8_lossy(bytes)
        .trim_matches(|c: char| c.is_whitespace() || c == '\0')
        .to_string()
}

fn decode_regions(code: &str) -> Vec<String> {
    let mut regions = Vec::new();
    for ch in code.chars() {
        match ch {
            'J' => regions.push("Japan / Asia (NTSC-J)".to_string()),
            'U' => regions.push("North America / USA (NTSC-U)".to_string()),
            'E' => regions.push("Europe / Australia (PAL)".to_string()),
            'T' => regions.push("Taiwan / Southeast Asia".to_string()),
            'K' => regions.push("Korea".to_string()),
            'A' => regions.push("Latin America / Brazil".to_string()),
            'B' => regions.push("Brazil".to_string()),
            _ => {}
        }
    }
    if regions.is_empty() {
        regions.push(format!("Region Code ({})", code));
    }
    regions
}

fn decode_peripherals(code: &str) -> Vec<String> {
    let mut periphs = Vec::new();
    for ch in code.chars() {
        match ch {
            'J' => periphs.push("Standard Control Pad".to_string()),
            'A' => periphs.push("Analog Controller (3D Control Pad / Mission Stick)".to_string()),
            'M' => periphs.push("Saturn Mouse / Shuttle Mouse".to_string()),
            'K' => periphs.push("Saturn Keyboard".to_string()),
            'G' => periphs.push("Virtua Gun / Light Gun".to_string()),
            'S' => periphs.push("Arcade Racer / Steering Wheel".to_string()),
            'T' => periphs.push("Multi-Tap (Up to 12 Players)".to_string()),
            'C' => periphs.push("Floppy Disk Drive (FDD)".to_string()),
            'P' => periphs.push("MIDI Interface / Sound Box".to_string()),
            _ => {}
        }
    }
    if periphs.is_empty() {
        periphs.push("Standard Control Pad".to_string());
    }
    periphs
}

/// Resolve a referenced disc or track file from a CUE sheet.
///
/// Handles:
/// 1. Windows-style paths (e.g. `C:\Games\Track01.bin` or `.\Track01.bin`)
/// 2. Case-insensitivity (e.g. `GAME.BIN` vs `game.bin` vs `Game.Bin`)
/// 3. Common extension mismatches (e.g. CUE points to `.iso` but file is `.bin`, `.img`, `.raw`, `.mdf`, or vice-versa)
/// 4. Common Track naming conventions (e.g. `Track 01.bin`, `Track 1.bin`, `(Track 1).bin`)
/// 5. Files extracted into subdirectories or parent directories within archive temp folders
/// 6. Single disc image fallback (if there is only one data image in the directory, it's used)
pub fn resolve_cue_track(cue_path: &Path, referenced_name: &str) -> Option<PathBuf> {
    let parent_dir = cue_path.parent().unwrap_or_else(|| Path::new("."));

    // 1. Clean referenced name: strip quotes, trim whitespace
    let clean = referenced_name.trim().trim_matches('"').trim_matches('\'');
    let normalized = clean.replace('\\', "/");
    let bare_name = Path::new(&normalized)
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or(&normalized);

    // 2. Direct exact check if referenced_name is non-empty
    if !clean.is_empty() {
        let direct = parent_dir.join(clean);
        if direct.is_file() {
            return Some(direct);
        }

        let bare_path = parent_dir.join(bare_name);
        if bare_path.is_file() {
            return Some(bare_path);
        }

        // 3. Case-insensitive search in parent_dir
        if let Some(found) = find_case_insensitive(parent_dir, bare_name) {
            return Some(found);
        }
    }

    // 4. Extension swaps for disc images:
    // If referenced file has an extension like .iso, .bin, .img, .raw, .mdf, try all alternatives
    let disc_extensions = ["bin", "iso", "img", "raw", "mdf"];
    let bare_path_obj = Path::new(bare_name);
    let stem = if !bare_name.is_empty() {
        bare_path_obj
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or(bare_name)
    } else {
        cue_path
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("")
    };

    if !stem.is_empty() {
        for alt_ext in &disc_extensions {
            let alt_name = format!("{}.{}", stem, alt_ext);
            if let Some(found) = find_case_insensitive(parent_dir, &alt_name) {
                return Some(found);
            }
        }
    }

    // Also try CUE file stem with alternative extensions
    let cue_stem = cue_path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("");
    if !cue_stem.is_empty() && cue_stem != stem {
        for alt_ext in &disc_extensions {
            let alt_name = format!("{}.{}", cue_stem, alt_ext);
            if let Some(found) = find_case_insensitive(parent_dir, &alt_name) {
                return Some(found);
            }
        }
    }

    // 5. Track pattern matches (e.g., "Track 1", "Track 01", "track1")
    if let Ok(entries) = fs::read_dir(parent_dir) {
        let mut candidates = Vec::new();
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_file() {
                let e_ext = path
                    .extension()
                    .and_then(|e| e.to_str())
                    .unwrap_or("")
                    .to_lowercase();
                if disc_extensions.contains(&e_ext.as_str()) {
                    let name = path
                        .file_name()
                        .and_then(|n| n.to_str())
                        .unwrap_or("")
                        .to_lowercase();
                    if name.contains("track 1")
                        || name.contains("track 01")
                        || name.contains("track1")
                        || name.contains("track01")
                    {
                        return Some(path);
                    }
                    candidates.push(path);
                }
            }
        }

        // If there is only ONE data disc image in parent_dir, it must be the data track
        if candidates.len() == 1 {
            return Some(candidates.remove(0));
        }
    }

    // 6. Search in entire temp / parent directory tree
    let root_search_dir = if parent_dir
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("")
        .starts_with("saturnmac_")
    {
        parent_dir
    } else if let Some(grandparent) = parent_dir.parent() {
        if grandparent
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("")
            .starts_with("saturnmac_")
        {
            grandparent
        } else {
            parent_dir
        }
    } else {
        parent_dir
    };

    if let Some(found) = search_recursive_for_disc(root_search_dir, stem, &disc_extensions) {
        return Some(found);
    }

    None
}

fn find_case_insensitive(dir: &Path, target_filename: &str) -> Option<PathBuf> {
    let target_lower = target_filename.to_lowercase();
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_file() {
                if let Some(fname) = path.file_name().and_then(|n| n.to_str()) {
                    if fname.to_lowercase() == target_lower {
                        return Some(path);
                    }
                }
            }
        }
    }
    None
}

fn search_recursive_for_disc(dir: &Path, stem: &str, valid_exts: &[&str]) -> Option<PathBuf> {
    let stem_lower = stem.to_lowercase();
    let mut disc_candidates = Vec::new();
    let mut track1_candidate = None;

    let mut stack = vec![dir.to_path_buf()];
    while let Some(current_dir) = stack.pop() {
        if let Ok(entries) = fs::read_dir(&current_dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_dir() {
                    stack.push(path);
                } else if path.is_file() {
                    let ext = path
                        .extension()
                        .and_then(|e| e.to_str())
                        .unwrap_or("")
                        .to_lowercase();
                    if valid_exts.contains(&ext.as_str()) {
                        let fname = path
                            .file_name()
                            .and_then(|n| n.to_str())
                            .unwrap_or("")
                            .to_lowercase();
                        if !stem_lower.is_empty()
                            && (fname.starts_with(&stem_lower) || stem_lower.starts_with(&fname))
                        {
                            return Some(path);
                        }
                        if fname.contains("track 1")
                            || fname.contains("track 01")
                            || fname.contains("track1")
                        {
                            track1_candidate = Some(path.clone());
                        }
                        disc_candidates.push(path);
                    }
                }
            }
        }
    }

    if let Some(t1) = track1_candidate {
        return Some(t1);
    }
    if disc_candidates.len() == 1 {
        return Some(disc_candidates.remove(0));
    }
    disc_candidates.into_iter().next()
}

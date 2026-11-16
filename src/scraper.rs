use std::process::Command;
use std::fs;

pub const EMBEDDED_SATURN_TITLES: &str = include_str!("../assets/saturn_titles.txt");

pub struct GameArtScraper;

impl GameArtScraper {
    /// Attempt to find and download authentic Sega Saturn box art from the internet.
    /// Returns the raw PNG bytes if successful, or None if offline/not found.
    pub fn fetch_boxart(title: &str, product_id: &str, regions: &[String]) -> Option<Vec<u8>> {
        println!("🌐 Cercant caràtula oficial per a \"{}\" ({}) a internet...", title, product_id);

        let clean_title = Self::clean_title_for_search(title);
        let candidates = Self::build_candidate_filenames(&clean_title, regions);

        // 1. Try direct candidates (both HTTPS GitHub and HTTP Libretro)
        for filename in &candidates {
            if let Some(bytes) = Self::download_boxart_by_filename(filename) {
                println!("  ✅ S'ha trobat la caràtula oficial exacta a Libretro: {}", filename);
                return Some(bytes);
            }
        }

        // 2. If direct candidates fail, perform fuzzy search against all 2,294 known Saturn box arts
        println!("  🔎 Fent cerca de caràtules amb noms similars per a \"{}\"...", clean_title);
        let similar = Self::find_similar_boxarts(&clean_title, regions, 10);
        if !similar.is_empty() {
            println!("  💡 Caràtules amb títols més semblants trobades:");
            for (i, name) in similar.iter().take(4).enumerate() {
                println!("    {}. {}", i + 1, name);
            }

            for matched_filename in &similar {
                if let Some(bytes) = Self::download_boxart_by_filename(matched_filename) {
                    println!("  ✅ S'ha seleccionat i descarregat la caràtula més semblant: {}", matched_filename);
                    return Some(bytes);
                }
            }
        }

        println!("  ℹ️ No s'ha pogut descarregar la caràtula online. S'utilitzarà la icona integrada d'alta resolució.");
        None
    }

    /// Finds the closest matching box art filenames from the 2,294 Saturn database
    pub fn find_similar_boxarts(query: &str, regions: &[String], limit: usize) -> Vec<String> {
        let clean_q = query.replace('\0', "").trim().to_lowercase();
        let query_words: Vec<&str> = clean_q
            .split(|c: char| !c.is_alphanumeric())
            .filter(|w| !w.is_empty())
            .collect();

        if query_words.is_empty() {
            return Vec::new();
        }

        let reg_str = regions.join(" ").to_uppercase();
        let pref_region = if reg_str.contains('J') || reg_str.contains("JAPAN") {
            "japan"
        } else if reg_str.contains('E') || reg_str.contains("EUROPE") {
            "europe"
        } else {
            "usa"
        };

        let mut scored: Vec<(String, i32)> = Vec::new();

        for line in EMBEDDED_SATURN_TITLES.lines() {
            let filename = line.trim();
            if filename.is_empty() || !filename.ends_with(".png") {
                continue;
            }

            let base_name = filename.strip_suffix(".png").unwrap_or(filename);
            let lower = base_name.to_lowercase();

            let mut score = 0i32;

            // Direct substring match
            if lower.contains(&clean_q) {
                score += 80;
                if lower.starts_with(&clean_q) {
                    score += 40;
                }
            }

            // Word-level matching
            let line_words: Vec<&str> = lower
                .split(|c: char| !c.is_alphanumeric())
                .filter(|w| !w.is_empty())
                .collect();

            let mut matched_words_count = 0;
            for qw in &query_words {
                if line_words.contains(qw) {
                    matched_words_count += 1;
                    score += 25;
                } else if line_words.iter().any(|lw| lw.starts_with(qw) || qw.starts_with(lw)) {
                    score += 12;
                }
            }

            // Bonus if all query words are present
            if matched_words_count == query_words.len() && !query_words.is_empty() {
                score += 50;
            }

            // Region preference bonus
            if score > 0 {
                if lower.contains(pref_region) {
                    score += 20;
                }
                if pref_region == "usa" && lower.contains("usa, brazil") {
                    score += 25;
                }
                // Penalty for very different lengths to favor closer titles
                let len_diff = (lower.len() as i32 - clean_q.len() as i32).abs();
                score -= len_diff / 5;

                scored.push((filename.to_string(), score));
            }
        }

        // Sort by score descending
        scored.sort_by(|a, b| b.1.cmp(&a.1));

        scored.into_iter().take(limit).map(|(name, _)| name).collect()
    }

    /// Downloads a box art file by trying HTTPS GitHub Raw and HTTP Libretro
    fn download_boxart_by_filename(filename: &str) -> Option<Vec<u8>> {
        let encoded = urlencoding_simple(filename);

        // 1. Try HTTPS GitHub raw (bypasses ATS)
        let https_url = format!(
            "https://raw.githubusercontent.com/libretro-thumbnails/Sega_-_Saturn/master/Named_Boxarts/{}",
            encoded
        );
        if let Some(bytes) = Self::download_file(&https_url) {
            if bytes.len() > 1024 && &bytes[0..4] == b"\x89PNG" {
                return Some(bytes);
            }
        }

        // 2. Try HTTP Libretro
        let http_url = format!(
            "http://thumbnails.libretro.com/Sega%20-%20Saturn/Named_Boxarts/{}",
            encoded
        );
        if let Some(bytes) = Self::download_file(&http_url) {
            if bytes.len() > 1024 && &bytes[0..4] == b"\x89PNG" {
                return Some(bytes);
            }
        }

        None
    }

    /// Cleans a Saturn game title string (removes trailing ellipsis, extra spaces, etc.)
    pub fn clean_title_for_search(title: &str) -> String {
        let mut clean = title.replace('\0', "").trim().to_string();
        if clean.ends_with("...") {
            clean = clean.trim_end_matches('.').trim().to_string();
        }
        // Normalize multiple spaces
        let words: Vec<&str> = clean.split_whitespace().collect();
        let words_titlecased: Vec<String> = words
            .iter()
            .map(|w| {
                if w.len() <= 2 && w.chars().all(|c| c.is_alphabetic()) {
                    w.to_uppercase()
                } else {
                    let mut chars = w.chars();
                    match chars.next() {
                        None => String::new(),
                        Some(f) => f.to_uppercase().collect::<String>() + &chars.as_str().to_lowercase(),
                    }
                }
            })
            .collect();
        words_titlecased.join(" ")
    }

    /// Build candidate filenames matching Libretro naming conventions
    fn build_candidate_filenames(title: &str, regions: &[String]) -> Vec<String> {
        let mut candidates = Vec::new();
        let reg_str = regions.join(" ").to_uppercase();

        let is_europe = reg_str.contains('E') || reg_str.contains("EUROPE");
        let is_japan = reg_str.contains('J') || reg_str.contains("JAPAN");

        if !is_europe && !is_japan {
            // USA / North America
            candidates.push(format!("{} (USA, Brazil).png", title));
            candidates.push(format!("{} (USA).png", title));
        }
        if is_europe {
            candidates.push(format!("{} (Europe).png", title));
        }
        if is_japan {
            candidates.push(format!("{} (Japan).png", title));
            candidates.push(format!("{} (Japan) (1M).png", title));
            candidates.push(format!("{} (Japan) (2M).png", title));
        }

        // Generic fallback candidates
        candidates.push(format!("{} (USA, Brazil).png", title));
        candidates.push(format!("{} (USA).png", title));
        candidates.push(format!("{} (Europe).png", title));
        candidates.push(format!("{} (Japan).png", title));
        candidates.push(format!("{}.png", title));

        candidates
    }

    /// Downloads a URL into memory using system curl (with timeout)
    fn download_file(url: &str) -> Option<Vec<u8>> {
        let tmp_path = std::env::temp_dir().join(format!("saturn_art_{}.tmp", std::process::id()));
        let status = Command::new("curl")
            .args([
                "-sL",
                "--max-time", "12",
                "--connect-timeout", "5",
                url,
                "-o",
                tmp_path.to_str().unwrap_or(""),
            ])
            .status()
            .ok()?;

        if status.success() && tmp_path.exists() {
            let bytes = fs::read(&tmp_path).ok();
            let _ = fs::remove_file(&tmp_path);
            bytes
        } else {
            let _ = fs::remove_file(&tmp_path);
            None
        }
    }
}

pub fn urlencoding_simple(s: &str) -> String {
    let mut out = String::new();
    for b in s.bytes() {
        match b {
            b'a'..=b'z' | b'A'..=b'Z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(b as char);
            }
            b' ' => out.push_str("%20"),
            b'(' => out.push_str("%28"),
            b')' => out.push_str("%29"),
            b',' => out.push_str("%2C"),
            b'\'' => out.push_str("%27"),
            _ => out.push_str(&format!("%{:02X}", b)),
        }
    }
    out
}

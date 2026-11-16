use std::process::Command;
use std::fs;

pub struct GameArtScraper;

impl GameArtScraper {
    /// Attempt to find and download authentic Sega Saturn box art from the internet.
    /// Returns the raw PNG bytes if successful, or None if offline/not found.
    pub fn fetch_boxart(title: &str, product_id: &str, regions: &[String]) -> Option<Vec<u8>> {
        println!("🌐 Cercant caràtula oficial per a \"{}\" ({}) a internet...", title, product_id);

        let clean_title = Self::clean_title_for_search(title);
        let candidates = Self::build_candidate_filenames(&clean_title, regions);

        // 1. Try direct Libretro thumbnail URLs
        for filename in &candidates {
            let encoded_filename = urlencoding_simple(filename);
            let url = format!(
                "http://thumbnails.libretro.com/Sega%20-%20Saturn/Named_Boxarts/{}",
                encoded_filename
            );

            if let Some(bytes) = Self::download_file(&url) {
                if bytes.len() > 1024 && &bytes[0..4] == b"\x89PNG" {
                    println!("  ✅ S'ha trobat la caràtula oficial a Libretro: {}", filename);
                    return Some(bytes);
                }
            }
        }

        // 2. If direct candidates fail, search the Libretro Saturn thumbnails index
        println!("  🔎 Fent cerca profunda a l'índex de caràtules de Sega Saturn...");
        if let Some(matched_filename) = Self::search_libretro_index(&clean_title, regions) {
            let encoded = urlencoding_simple(&matched_filename);
            let url = format!(
                "http://thumbnails.libretro.com/Sega%20-%20Saturn/Named_Boxarts/{}",
                encoded
            );
            if let Some(bytes) = Self::download_file(&url) {
                if bytes.len() > 1024 && &bytes[0..4] == b"\x89PNG" {
                    println!("  ✅ S'ha trobat la caràtula coincident: {}", matched_filename);
                    return Some(bytes);
                }
            }
        }

        println!("  ℹ️ No s'ha pogut descarregar la caràtula online. S'utilitzarà la icona integrada d'alta resolució.");
        None
    }

    /// Cleans a Saturn game title string (removes trailing ellipsis, extra spaces, etc.)
    fn clean_title_for_search(title: &str) -> String {
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

    /// Search the Libretro Saturn thumbnails index for a matching game title
    fn search_libretro_index(title: &str, regions: &[String]) -> Option<String> {
        let index_url = "http://thumbnails.libretro.com/Sega%20-%20Saturn/Named_Boxarts/";
        let index_html = Self::download_file(index_url)?;
        let text = String::from_utf8_lossy(&index_html);

        let query = title.to_lowercase();
        let query_words: Vec<&str> = query.split_whitespace().collect();
        if query_words.is_empty() {
            return None;
        }

        let reg_str = regions.join(" ").to_uppercase();
        let pref_region = if reg_str.contains('J') {
            "japan"
        } else if reg_str.contains('E') {
            "europe"
        } else {
            "usa"
        };

        let mut best_match: Option<String> = None;
        let mut best_score = 0;

        for line in text.lines() {
            if let Some(href_start) = line.find("href=\"") {
                let rest = &line[href_start + 6..];
                if let Some(href_end) = rest.find('"') {
                    let filename_raw = &rest[..href_end];
                    if filename_raw.ends_with(".png") {
                        let filename = percent_decode(filename_raw);
                        let lower = filename.to_lowercase();

                        // Check if all major words match
                        let all_words = query_words.iter().all(|w| lower.contains(w));
                        if all_words {
                            let mut score = 10;
                            if lower.contains(pref_region) {
                                score += 20;
                            }
                            if lower.contains("usa, brazil") && pref_region == "usa" {
                                score += 25;
                            }
                            if score > best_score {
                                best_score = score;
                                best_match = Some(filename);
                            }
                        }
                    }
                }
            }
        }

        best_match
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

fn urlencoding_simple(s: &str) -> String {
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
            _ => out.push_str(&format!("%{:02X}", b)),
        }
    }
    out
}

fn percent_decode(s: &str) -> String {
    let mut result = Vec::new();
    let bytes = s.as_bytes();
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            if let Ok(val) = u8::from_str_radix(std::str::from_utf8(&bytes[i + 1..i + 3]).unwrap_or(""), 16) {
                result.push(val);
                i += 3;
                continue;
            }
        }
        result.push(bytes[i]);
        i += 1;
    }
    String::from_utf8_lossy(&result).to_string()
}

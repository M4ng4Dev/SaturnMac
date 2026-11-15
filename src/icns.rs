use anyhow::Result;

/// Generate a valid Apple .icns file embedding PNG icons.
///
/// macOS supports standard PNG chunks:
/// - 'ic07' = 128x128 PNG
/// - 'ic08' = 256x256 PNG
/// - 'ic09' = 512x512 PNG
pub struct IcnsBuilder;

impl IcnsBuilder {
    /// Create an ICNS file bytes from raw PNG data (stored in 'ic09' 512x512).
    pub fn from_png(png_bytes: &[u8]) -> Result<Vec<u8>> {
        let mut icns = Vec::new();
        icns.extend_from_slice(b"icns");
        icns.extend_from_slice(&[0u8; 4]); // Size placeholder

        let chunk_len = (8 + png_bytes.len()) as u32;
        icns.extend_from_slice(b"ic09");
        icns.extend_from_slice(&chunk_len.to_be_bytes());
        icns.extend_from_slice(png_bytes);

        let total_size = icns.len() as u32;
        icns[4..8].copy_from_slice(&total_size.to_be_bytes());
        Ok(icns)
    }

    /// Build a multi-resolution ICNS containing 128x128, 256x256, and 512x512 chunks
    pub fn build_multi_chunk_icns(png_512: &[u8], png_256: &[u8], png_128: &[u8]) -> Result<Vec<u8>> {
        let mut icns = Vec::new();
        icns.extend_from_slice(b"icns");
        icns.extend_from_slice(&[0u8; 4]);

        let chunks: &[(&[u8; 4], &[u8])] = &[
            (b"ic07", png_128),
            (b"ic08", png_256),
            (b"ic09", png_512),
        ];

        for (tag, data) in chunks {
            let chunk_len = (8 + data.len()) as u32;
            icns.extend_from_slice(*tag);
            icns.extend_from_slice(&chunk_len.to_be_bytes());
            icns.extend_from_slice(data);
        }

        let total_size = icns.len() as u32;
        icns[4..8].copy_from_slice(&total_size.to_be_bytes());
        Ok(icns)
    }

    /// High resolution native macOS ICNS for Sonic R
    pub fn sonic_r_icon() -> Vec<u8> {
        const P512: &[u8] = include_bytes!("../assets/icons/sonic_r.png");
        const P256: &[u8] = include_bytes!("../assets/icons/sonic_r_256.png");
        const P128: &[u8] = include_bytes!("../assets/icons/sonic_r_128.png");
        Self::build_multi_chunk_icns(P512, P256, P128)
            .unwrap_or_else(|_| Self::from_png(P512).unwrap_or_default())
    }

    /// High resolution native macOS ICNS for Sega Saturn default
    pub fn default_saturn_icon() -> Vec<u8> {
        const P512: &[u8] = include_bytes!("../assets/icons/saturn_default.png");
        const P256: &[u8] = include_bytes!("../assets/icons/saturn_default_256.png");
        const P128: &[u8] = include_bytes!("../assets/icons/saturn_default_128.png");
        Self::build_multi_chunk_icns(P512, P256, P128)
            .unwrap_or_else(|_| Self::from_png(P512).unwrap_or_default())
    }

    /// Automatically selects best icon based on game title or product ID
    pub fn icon_for_game(title: &str, product_id: &str) -> Vec<u8> {
        let t_upper = title.to_uppercase();
        let p_upper = product_id.to_uppercase();
        if t_upper.contains("SONIC R") || p_upper.contains("MK-81800") || p_upper.contains("GS-9170") {
            Self::sonic_r_icon()
        } else {
            Self::default_saturn_icon()
        }
    }
}

use anyhow::{Context, Result};
use image::imageops::FilterType;
use image::{DynamicImage, GenericImageView, ImageEncoder, RgbaImage};
use std::io::Cursor;
use std::path::Path;

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

    /// Process arbitrary image bytes (box art of any size or aspect ratio),
    /// square-fit it with clean padding/squircle styling, and produce a Retina multi-chunk ICNS.
    pub fn from_image_bytes(image_bytes: &[u8]) -> Result<Vec<u8>> {
        let img = image::load_from_memory(image_bytes)
            .context("Failed to decode image data")?;

        let square_512 = Self::fit_to_square(&img, 512);
        let square_256 = image::imageops::resize(&square_512, 256, 256, FilterType::Lanczos3);
        let square_128 = image::imageops::resize(&square_512, 128, 128, FilterType::Lanczos3);

        let p512 = Self::encode_png(&square_512)?;
        let p256 = Self::encode_png(&square_256)?;
        let p128 = Self::encode_png(&square_128)?;

        Self::build_multi_chunk_icns(&p512, &p256, &p128)
    }

    /// Fit any image (including rectangular longboxes) into a centered square canvas
    pub fn fit_to_square(img: &DynamicImage, target_size: u32) -> RgbaImage {
        let (w, h) = img.dimensions();
        let mut canvas = RgbaImage::new(target_size, target_size);

        if w == h {
            // Already square
            return image::imageops::resize(img, target_size, target_size, FilterType::Lanczos3);
        }

        // Calculate aspect-fit dimensions
        let aspect = w as f32 / h as f32;
        let (fit_w, fit_h) = if aspect < 1.0 {
            // Taller than wide (typical Saturn US/EU longbox)
            let fit_h = target_size;
            let fit_w = ((target_size as f32) * aspect).round() as u32;
            (fit_w.max(1), fit_h)
        } else {
            // Wider than tall
            let fit_w = target_size;
            let fit_h = ((target_size as f32) / aspect).round() as u32;
            (fit_w, fit_h.max(1))
        };

        let scaled = image::imageops::resize(img, fit_w, fit_h, FilterType::Lanczos3);
        let offset_x = (target_size - fit_w) / 2;
        let offset_y = (target_size - fit_h) / 2;

        image::imageops::overlay(&mut canvas, &scaled, offset_x as i64, offset_y as i64);
        canvas
    }

    /// Encode an RgbaImage to PNG bytes
    pub fn encode_png(img: &RgbaImage) -> Result<Vec<u8>> {
        let mut buffer = Cursor::new(Vec::new());
        let encoder = image::codecs::png::PngEncoder::new(&mut buffer);
        encoder.write_image(
            img.as_raw(),
            img.width(),
            img.height(),
            image::ExtendedColorType::Rgba8,
        )?;
        Ok(buffer.into_inner())
    }

    /// Export standard iOS / iPadOS icon bundle PNG files
    pub fn export_ios_icons(image_bytes: &[u8], dest_dir: &Path) -> Result<()> {
        let img = image::load_from_memory(image_bytes)
            .context("Failed to decode image data for iOS")?;

        let sizes = &[
            (120, "AppIcon60x60@2x.png"),
            (180, "AppIcon60x60@3x.png"),
            (152, "AppIcon76x76@2x.png"),
            (167, "AppIcon83.5x83.5@2x.png"),
            (512, "AppIcon512.png"),
            (1024, "AppIcon1024.png"),
        ];

        std::fs::create_dir_all(dest_dir)?;

        for (sz, filename) in sizes {
            let square = Self::fit_to_square(&img, *sz);
            let png_bytes = Self::encode_png(&square)?;
            std::fs::write(dest_dir.join(filename), png_bytes)?;
        }

        Ok(())
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

    /// Automatically selects best built-in fallback icon based on game title or product ID
    pub fn fallback_icon_for_game(title: &str, product_id: &str) -> Vec<u8> {
        let t_upper = title.to_uppercase();
        let p_upper = product_id.to_uppercase();
        if t_upper.contains("SONIC R") || p_upper.contains("MK-81800") || p_upper.contains("GS-9170") {
            Self::sonic_r_icon()
        } else {
            Self::default_saturn_icon()
        }
    }

    /// Backwards-compatible alias for fallback_icon_for_game
    #[allow(dead_code)]
    pub fn icon_for_game(title: &str, product_id: &str) -> Vec<u8> {
        Self::fallback_icon_for_game(title, product_id)
    }
}

use saturnmac::bundler::AppBundleOptions;
use saturnmac::parser::SaturnDiscParser;
use saturnmac::release::ReleaseManager;
use std::fs::File;
use std::io::Write;
use std::path::Path;

fn create_mock_disc_image(path: &Path, title: &str, product: &str) {
    let mut sector = vec![0u8; 2352 * 16];
    sector[0..12].copy_from_slice(&[0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00]);
    sector[12..15].copy_from_slice(&[0x00, 0x02, 0x00]);
    sector[15] = 0x01;

    let ip = &mut sector[16..16 + 256];
    copy_str("SEGA SEGASATURN ", &mut ip[0..16]);
    copy_str("SEGA ENTERPRISES", &mut ip[16..32]);
    copy_str(product, &mut ip[32..42]);
    copy_str("V1.000", &mut ip[42..48]);
    copy_str("19971118", &mut ip[48..56]);
    copy_str("CD-1/1  ", &mut ip[56..64]);
    copy_str("U       ", &mut ip[64..74]);
    copy_str("J       ", &mut ip[74..80]);
    copy_str(title, &mut ip[96..208]);

    let mut f = File::create(path).unwrap();
    f.write_all(&sector).unwrap();
}

fn copy_str(s: &str, slice: &mut [u8]) {
    slice.fill(b' ');
    let bytes = s.as_bytes();
    let len = bytes.len().min(slice.len());
    slice[..len].copy_from_slice(&bytes[..len]);
}

#[test]
fn test_multiplatform_release_generation() {
    let temp_dir = std::env::temp_dir().join(format!("saturn_release_test_{}", std::process::id()));
    std::fs::create_dir_all(&temp_dir).unwrap();

    let rom_path = temp_dir.join("Sonic R.bin");
    create_mock_disc_image(&rom_path, "SONIC R", "MK-81800");

    let info = SaturnDiscParser::parse(&rom_path).unwrap();
    let out_dir = temp_dir.join("releases");

    let options = AppBundleOptions {
        internal_resolution: 8,
        metal_rendering: true,
        promotion_120hz: true,
        widescreen_anamorphic: false,
        crt_shader: false,
        dedither: false,
        smoothing: true,
        icon_png_path: None,
    };

    let artifacts = ReleaseManager::build_all_releases(&rom_path, &info, &out_dir, &options).unwrap();

    // Verify macOS .app bundle
    assert!(artifacts.mac_app.exists());
    assert!(artifacts.mac_app.join("Contents/Info.plist").exists());
    assert!(artifacts.mac_app.join("Contents/Resources/AppIcon.icns").exists());

    // Verify macOS .dmg or .zip
    assert!(artifacts.mac_dmg.exists());

    // Verify iOS/iPadOS .ipa
    assert!(artifacts.ios_ipa.exists());
    assert!(artifacts.ios_ipa.to_string_lossy().ends_with("(iOS-iPadOS).ipa"));

    // Cleanup
    let _ = std::fs::remove_dir_all(&temp_dir);
}

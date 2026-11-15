use saturnmac::bundler::{AppBundleOptions, AppBundler};
use saturnmac::parser::SaturnDiscParser;
use std::fs;
use std::path::Path;

#[test]
fn test_mock_disc_creation_and_parsing() {
    let test_dir = Path::new("target/test_output");
    fs::create_dir_all(test_dir).unwrap();

    let bin_path = test_dir.join("panzer_dragoon.bin");
    let cue_path = test_dir.join("panzer_dragoon.cue");

    // Generate a mock binary disc with Japanese region
    let mut sector = vec![0u8; 2352 * 16];
    // Sync
    sector[0..12].copy_from_slice(&[0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00]);
    sector[12..15].copy_from_slice(&[0x00, 0x02, 0x00]);
    sector[15] = 0x01;

    let ip = &mut sector[16..16 + 256];
    fill_slice(b"SEGA SEGASATURN ", &mut ip[0..16]);
    fill_slice(b"SEGA ENTERPRISES", &mut ip[16..32]);
    fill_slice(b"GS-9001   ", &mut ip[32..42]);
    fill_slice(b"V1.000", &mut ip[42..48]);
    fill_slice(b"19950310", &mut ip[48..56]);
    fill_slice(b"CD-1/1  ", &mut ip[56..64]);
    fill_slice(b"J         ", &mut ip[64..74]);
    fill_slice(b"J         ", &mut ip[74..80]);
    fill_slice(b"PANZER DRAGOON", &mut ip[96..208]);

    fs::write(&bin_path, &sector).unwrap();

    // Create CUE sheet
    let cue_content = format!(
        "FILE \"{}\" BINARY\n  TRACK 01 MODE1/2352\n    INDEX 01 00:00:00\n",
        bin_path.file_name().unwrap().to_str().unwrap()
    );
    fs::write(&cue_path, cue_content).unwrap();

    // Parse via CUE
    let info = SaturnDiscParser::parse(&cue_path).expect("Should parse CUE");
    assert_eq!(info.hardware_id, "SEGA SEGASATURN");
    assert_eq!(info.product_id, "GS-9001");
    assert_eq!(info.title, "PANZER DRAGOON");
    assert_eq!(info.region_codes, "J");
    assert!(info.regions[0].contains("Japan"));
    assert_eq!(info.sector_mode, "RAW (2352 bytes)");

    // Test creating .app bundle
    let options = AppBundleOptions::default();
    let app_bundle = AppBundler::create_app_bundle(&cue_path, &info, test_dir, &options)
        .expect("Should create .app bundle");

    assert!(app_bundle.exists());
    assert!(app_bundle.join("Contents/Info.plist").exists());
    assert!(app_bundle.join("Contents/PkgInfo").exists());
    assert!(app_bundle.join("Contents/MacOS/Launcher").exists());
    assert!(app_bundle.join("Contents/Resources/AppIcon.icns").exists());
    assert!(app_bundle.join("Contents/Resources/Config/saturn.json").exists());
    assert!(app_bundle.join("Contents/Resources/Game/panzer_dragoon.cue").exists());
    assert!(app_bundle.join("Contents/Resources/Game/panzer_dragoon.bin").exists());

    // Verify Info.plist contains expected bundle ID
    let plist = fs::read_to_string(app_bundle.join("Contents/Info.plist")).unwrap();
    assert!(plist.contains("com.saturnmac.gs9001"));
}

fn fill_slice(src: &[u8], dest: &mut [u8]) {
    dest.fill(b' ');
    let len = src.len().min(dest.len());
    dest[..len].copy_from_slice(&src[..len]);
}

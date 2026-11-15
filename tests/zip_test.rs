use saturnmac::archive::ZipExtractor;
use saturnmac::parser::SaturnDiscParser;
use std::fs::{self, File};
use std::io::Write;
use zip::write::SimpleFileOptions;

#[test]
fn test_zip_archive_extraction_and_parsing() {
    let temp_dir = std::env::temp_dir().join(format!("saturnmac_test_zip_{}", std::process::id()));
    fs::create_dir_all(&temp_dir).unwrap();

    let zip_path = temp_dir.join("sonic_test.zip");

    // 1. Create a mock Saturn disc binary
    let mut header = vec![0u8; 2048];
    header[0..15].copy_from_slice(b"SEGA SEGASATURN");
    header[0x20..0x28].copy_from_slice(b"MK-81800");
    header[0x60..0x67].copy_from_slice(b"SONIC R");
    header[0x40..0x41].copy_from_slice(b"U");

    // 2. Pack into a zip archive
    let file = File::create(&zip_path).unwrap();
    let mut zip = zip::ZipWriter::new(file);
    let options = SimpleFileOptions::default().compression_method(zip::CompressionMethod::Stored);

    zip.start_file("Sonic R.bin", options).unwrap();
    zip.write_all(&header).unwrap();

    let cue_content = "FILE \"Sonic R.bin\" BINARY\n  TRACK 01 MODE1/2048\n    INDEX 01 00:00:00\n";
    zip.start_file("Sonic R.cue", options).unwrap();
    zip.write_all(cue_content.as_bytes()).unwrap();

    zip.finish().unwrap();

    // 3. Test ZipExtractor
    let extracted_dir = ZipExtractor::extract_zip(&zip_path).unwrap();
    let primary = ZipExtractor::find_primary_rom(&extracted_dir).unwrap();
    assert!(primary.to_string_lossy().ends_with(".cue"));

    // 4. Test SaturnDiscParser directly on the .zip file
    let info = SaturnDiscParser::parse(&zip_path).unwrap();
    assert_eq!(info.product_id.trim(), "MK-81800");
    assert_eq!(info.title.trim(), "SONIC R");

    // Cleanup
    let _ = fs::remove_dir_all(&temp_dir);
    let _ = fs::remove_dir_all(&extracted_dir);
}

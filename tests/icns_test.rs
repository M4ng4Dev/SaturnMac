use saturnmac::icns::IcnsBuilder;

#[test]
fn test_default_saturn_icon_valid_icns() {
    let bytes = IcnsBuilder::default_saturn_icon();
    assert!(bytes.len() > 1000);
    assert_eq!(&bytes[0..4], b"icns");
    let total_len = u32::from_be_bytes([bytes[4], bytes[5], bytes[6], bytes[7]]) as usize;
    assert_eq!(bytes.len(), total_len);
}

#[test]
fn test_sonic_r_icon_valid_icns() {
    let bytes = IcnsBuilder::sonic_r_icon();
    assert!(bytes.len() > 1000);
    assert_eq!(&bytes[0..4], b"icns");
    let total_len = u32::from_be_bytes([bytes[4], bytes[5], bytes[6], bytes[7]]) as usize;
    assert_eq!(bytes.len(), total_len);
}

#[test]
fn test_icon_for_game_selection() {
    let sonic_bytes = IcnsBuilder::icon_for_game("SONIC R", "MK-81800");
    let default_bytes = IcnsBuilder::icon_for_game("PANZER DRAGOON", "MK-81008");
    assert_eq!(sonic_bytes, IcnsBuilder::sonic_r_icon());
    assert_eq!(default_bytes, IcnsBuilder::default_saturn_icon());
}

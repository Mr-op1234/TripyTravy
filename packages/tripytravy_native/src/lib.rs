pub mod crypto;
pub mod error;
pub mod pack;
pub mod seed;

pub use error::TtError;
pub use pack::{
    pack_container, unpack_container, TtrvHeader, UnpackedContainer, FLAG_AES256_GCM,
    FLAG_EMBEDDED_MAP_SLICE, FLAG_PIN_PROTECTED, FLAG_TEMPLATE_SANITIZED, FLAG_ZSTD, HEADER_SIZE,
    TAG_SIZE, TTRV_MAGIC, TTRV_VERSION_V1,
};

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_standard_pack_and_unpack_roundtrip() {
        let proto = b"mock-serialized-trip-package-protobuf";
        let assets = b"PDF-VOUCHER-BYTES-AND-WEBP-PHOTO-BYTES";

        let sealed = pack_container(proto, assets, None, false, false).expect("pack failed");
        assert_eq!(&sealed[0..4], b"TTRV");

        let unpacked = unpack_container(&sealed, None).expect("unpack failed");
        assert_eq!(unpacked.protobuf_bytes, proto);
        assert_eq!(unpacked.concatenated_assets, assets);
        assert_eq!(unpacked.header.flags, FLAG_ZSTD | FLAG_AES256_GCM);
    }

    #[test]
    fn test_pin_protected_mode_and_wrong_pin_rejection() {
        let proto = b"kyoto-private-itinerary";
        let assets = b"shinkansen-qr-code";

        let sealed = pack_container(proto, assets, Some("123456"), true, false).unwrap();
        assert_eq!(unpack_container(&sealed, None), Err(TtError::PinRequired));
        assert_eq!(
            unpack_container(&sealed, Some("999999")),
            Err(TtError::AuthenticationFailed)
        );

        let unpacked = unpack_container(&sealed, Some("123456")).unwrap();
        assert_eq!(unpacked.protobuf_bytes, proto);
    }

    #[test]
    fn test_header_aad_tamper_rejection() {
        let mut sealed = pack_container(b"swiss-trip", b"assets", None, false, false).unwrap();
        sealed[7] ^= 0x10;
        assert_eq!(
            unpack_container(&sealed, None),
            Err(TtError::AuthenticationFailed)
        );
    }
}

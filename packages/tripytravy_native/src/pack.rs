use rand::rngs::OsRng;
use rand::RngCore;

use crate::crypto::{decrypt_with_header_aad, derive_aes256_key, encrypt_with_header_aad};
use crate::error::TtError;

pub const TTRV_MAGIC: [u8; 4] = *b"TTRV";
pub const TTRV_VERSION_V1: u16 = 0x0001;
pub const HEADER_SIZE: usize = 40;
pub const TAG_SIZE: usize = 16;
pub const ZSTD_LEVEL: i32 = 6;

pub const FLAG_ZSTD: u16 = 0x0001;
pub const FLAG_AES256_GCM: u16 = 0x0002;
pub const FLAG_PIN_PROTECTED: u16 = 0x0004;
pub const FLAG_EMBEDDED_MAP_SLICE: u16 = 0x0008;
pub const FLAG_TEMPLATE_SANITIZED: u16 = 0x0010;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TtrvHeader {
    pub version: u16,
    pub flags: u16,
    pub file_salt: [u8; 16],
    pub iv: [u8; 12],
    pub ciphertext_length: u32,
}

impl TtrvHeader {
    pub fn to_bytes(&self) -> [u8; HEADER_SIZE] {
        let mut buf = [0u8; HEADER_SIZE];
        buf[0..4].copy_from_slice(&TTRV_MAGIC);
        buf[4..6].copy_from_slice(&self.version.to_be_bytes());
        buf[6..8].copy_from_slice(&self.flags.to_be_bytes());
        buf[8..24].copy_from_slice(&self.file_salt);
        buf[24..36].copy_from_slice(&self.iv);
        buf[36..40].copy_from_slice(&self.ciphertext_length.to_be_bytes());
        buf
    }

    pub fn from_bytes(bytes: &[u8]) -> Result<Self, TtError> {
        if bytes.len() < HEADER_SIZE {
            return Err(TtError::TruncatedContainer(bytes.len()));
        }
        if bytes[0..4] != TTRV_MAGIC {
            return Err(TtError::InvalidMagic);
        }
        let version = u16::from_be_bytes([bytes[4], bytes[5]]);
        if version != TTRV_VERSION_V1 {
            return Err(TtError::UnsupportedVersion(version));
        }
        let flags = u16::from_be_bytes([bytes[6], bytes[7]]);
        let mut file_salt = [0u8; 16];
        file_salt.copy_from_slice(&bytes[8..24]);
        let mut iv = [0u8; 12];
        iv.copy_from_slice(&bytes[24..36]);
        let ciphertext_length = u32::from_be_bytes([bytes[36], bytes[37], bytes[38], bytes[39]]);

        Ok(Self {
            version,
            flags,
            file_salt,
            iv,
            ciphertext_length,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UnpackedContainer {
    pub header: TtrvHeader,
    pub protobuf_bytes: Vec<u8>,
    pub concatenated_assets: Vec<u8>,
}

/// Builds the deterministic inner stream: [uint32_be proto_len][proto_bytes][asset_blobs],
/// compresses with zstd level 6, and seals into a TTRV v1 container with 40B Header AAD.
pub fn pack_container(
    protobuf_bytes: &[u8],
    concatenated_assets: &[u8],
    user_pin: Option<&str>,
    has_embedded_map_slice: bool,
    is_template_sanitized: bool,
) -> Result<Vec<u8>, TtError> {
    let proto_len = u32::try_from(protobuf_bytes.len())
        .map_err(|_| TtError::MalformedInnerStream("Protobuf exceeds 4 GiB".into()))?;

    let mut inner_stream = Vec::with_capacity(4 + protobuf_bytes.len() + concatenated_assets.len());
    inner_stream.extend_from_slice(&proto_len.to_be_bytes());
    inner_stream.extend_from_slice(protobuf_bytes);
    inner_stream.extend_from_slice(concatenated_assets);

    let compressed = zstd::encode_all(inner_stream.as_slice(), ZSTD_LEVEL)
        .map_err(|e| TtError::CompressionFailed(e.to_string()))?;

    let mut file_salt = [0u8; 16];
    let mut iv = [0u8; 12];
    OsRng.fill_bytes(&mut file_salt);
    OsRng.fill_bytes(&mut iv);

    let mut flags = FLAG_ZSTD | FLAG_AES256_GCM;
    if user_pin.is_some() {
        flags |= FLAG_PIN_PROTECTED;
    }
    if has_embedded_map_slice {
        flags |= FLAG_EMBEDDED_MAP_SLICE;
    }
    if is_template_sanitized {
        flags |= FLAG_TEMPLATE_SANITIZED;
    }

    let ciphertext_length = u32::try_from(compressed.len())
        .map_err(|_| TtError::MalformedInnerStream("Compressed stream exceeds 4 GiB".into()))?;

    let header = TtrvHeader {
        version: TTRV_VERSION_V1,
        flags,
        file_salt,
        iv,
        ciphertext_length,
    };
    let header_bytes = header.to_bytes();

    let key = derive_aes256_key(&file_salt, user_pin)?;
    let (ciphertext, auth_tag) = encrypt_with_header_aad(&key, &iv, &header_bytes, &compressed)?;

    let mut out = Vec::with_capacity(HEADER_SIZE + ciphertext.len() + TAG_SIZE);
    out.extend_from_slice(&header_bytes);
    out.extend_from_slice(&ciphertext);
    out.extend_from_slice(&auth_tag);
    Ok(out)
}

/// Verifies the 40B Header AAD and 16B GCM Auth Tag, decompresses the zstd stream,
/// and splits [proto_bytes] and [concatenated_assets].
pub fn unpack_container(
    container_bytes: &[u8],
    user_pin: Option<&str>,
) -> Result<UnpackedContainer, TtError> {
    if container_bytes.len() < HEADER_SIZE + TAG_SIZE {
        return Err(TtError::TruncatedContainer(container_bytes.len()));
    }

    let header = TtrvHeader::from_bytes(&container_bytes[0..HEADER_SIZE])?;
    let expected_total = HEADER_SIZE + (header.ciphertext_length as usize) + TAG_SIZE;
    if container_bytes.len() != expected_total {
        return Err(TtError::LengthMismatch {
            expected: expected_total,
            actual: container_bytes.len(),
        });
    }

    let pin_protected = (header.flags & FLAG_PIN_PROTECTED) != 0;
    if pin_protected && user_pin.is_none() {
        return Err(TtError::PinRequired);
    }

    let mut header_aad = [0u8; HEADER_SIZE];
    header_aad.copy_from_slice(&container_bytes[0..HEADER_SIZE]);

    let ct_end = HEADER_SIZE + (header.ciphertext_length as usize);
    let ciphertext = &container_bytes[HEADER_SIZE..ct_end];
    let mut auth_tag = [0u8; TAG_SIZE];
    auth_tag.copy_from_slice(&container_bytes[ct_end..expected_total]);

    let key = derive_aes256_key(&header.file_salt, if pin_protected { user_pin } else { None })?;
    let compressed = decrypt_with_header_aad(&key, &header.iv, &header_aad, ciphertext, &auth_tag)?;

    let decompressed = zstd::decode_all(compressed.as_slice())
        .map_err(|e| TtError::DecompressionFailed(e.to_string()))?;

    if decompressed.len() < 4 {
        return Err(TtError::MalformedInnerStream("Missing 4B protobuf length prefix".into()));
    }

    let proto_len = u32::from_be_bytes([
        decompressed[0],
        decompressed[1],
        decompressed[2],
        decompressed[3],
    ]) as usize;

    if decompressed.len() < 4 + proto_len {
        return Err(TtError::MalformedInnerStream("Protobuf length exceeds inner stream".into()));
    }

    let protobuf_bytes = decompressed[4..4 + proto_len].to_vec();
    let concatenated_assets = decompressed[4 + proto_len..].to_vec();

    Ok(UnpackedContainer {
        header,
        protobuf_bytes,
        concatenated_assets,
    })
}

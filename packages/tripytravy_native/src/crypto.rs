use aes_gcm::aead::{Aead, KeyInit, Payload};
use aes_gcm::{Aes256Gcm, Nonce};
use argon2::{Algorithm, Argon2, Params, Version};
use hkdf::Hkdf;
use sha2::Sha256;
use zeroize::Zeroizing;

use crate::error::TtError;
use crate::seed::reconstruct_secret_seed;

const INFO_STANDARD: &[u8] = b"TripyTravy-V1-Payload";
const INFO_PIN: &[u8] = b"TripyTravy-V1-PinPayload";
const ARGON2_M_COST_KIB: u32 = 19456;
const ARGON2_T_COST: u32 = 2;
const ARGON2_P_COST: u32 = 1;

/// Derives the 32-byte AES-256-GCM key using Standard HKDF or Argon2id + HKDF PIN mode.
pub fn derive_aes256_key(file_salt: &[u8; 16], user_pin: Option<&str>) -> Result<Zeroizing<[u8; 32]>, TtError> {
    let secret_seed = reconstruct_secret_seed();
    let mut okm = Zeroizing::new([0u8; 32]);

    match user_pin {
        None => {
            let hk = Hkdf::<Sha256>::new(Some(file_salt), &*secret_seed);
            hk.expand(INFO_STANDARD, &mut *okm)
                .map_err(|_| TtError::KeyDerivationFailed)?;
        }
        Some(pin) => {
            let params = Params::new(ARGON2_M_COST_KIB, ARGON2_T_COST, ARGON2_P_COST, Some(32))
                .map_err(|_| TtError::KeyDerivationFailed)?;
            let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);
            let mut pin_key = Zeroizing::new([0u8; 32]);
            argon2
                .hash_password_into(pin.as_bytes(), file_salt, &mut *pin_key)
                .map_err(|_| TtError::KeyDerivationFailed)?;

            let mut combined_ikm = Zeroizing::new([0u8; 64]);
            combined_ikm[..32].copy_from_slice(&*secret_seed);
            combined_ikm[32..].copy_from_slice(&*pin_key);

            let hk = Hkdf::<Sha256>::new(Some(file_salt), &*combined_ikm);
            hk.expand(INFO_PIN, &mut *okm)
                .map_err(|_| TtError::KeyDerivationFailed)?;
        }
    }

    Ok(okm)
}

/// Encrypts compressed inner stream with AES-256-GCM binding the 40-byte header as AAD.
/// Returns (ciphertext_without_tag, 16_byte_auth_tag).
pub fn encrypt_with_header_aad(
    key: &[u8; 32],
    iv: &[u8; 12],
    header_aad: &[u8; 40],
    plaintext: &[u8],
) -> Result<(Vec<u8>, [u8; 16]), TtError> {
    let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| TtError::KeyDerivationFailed)?;
    let nonce = Nonce::from_slice(iv);
    let mut full = cipher
        .encrypt(
            nonce,
            Payload {
                msg: plaintext,
                aad: header_aad,
            },
        )
        .map_err(|_| TtError::AuthenticationFailed)?;

    if full.len() < 16 {
        return Err(TtError::AuthenticationFailed);
    }
    let tag_offset = full.len() - 16;
    let mut tag = [0u8; 16];
    tag.copy_from_slice(&full[tag_offset..]);
    full.truncate(tag_offset);
    Ok((full, tag))
}

/// Verifies the 40-byte header AAD and 16-byte GCM tag, returning decrypted inner stream.
pub fn decrypt_with_header_aad(
    key: &[u8; 32],
    iv: &[u8; 12],
    header_aad: &[u8; 40],
    ciphertext: &[u8],
    auth_tag: &[u8; 16],
) -> Result<Vec<u8>, TtError> {
    let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| TtError::KeyDerivationFailed)?;
    let nonce = Nonce::from_slice(iv);
    let mut combined = Vec::with_capacity(ciphertext.len() + 16);
    combined.extend_from_slice(ciphertext);
    combined.extend_from_slice(auth_tag);

    cipher
        .decrypt(
            nonce,
            Payload {
                msg: &combined,
                aad: header_aad,
            },
        )
        .map_err(|_| TtError::AuthenticationFailed)
}

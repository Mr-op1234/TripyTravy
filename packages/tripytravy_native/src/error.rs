use std::fmt;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TtError {
    InvalidMagic,
    UnsupportedVersion(u16),
    TruncatedContainer(usize),
    LengthMismatch { expected: usize, actual: usize },
    PinRequired,
    KeyDerivationFailed,
    AuthenticationFailed,
    CompressionFailed(String),
    DecompressionFailed(String),
    MalformedInnerStream(String),
}

impl fmt::Display for TtError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            TtError::InvalidMagic => write!(f, "Invalid TTRV container magic bytes"),
            TtError::UnsupportedVersion(v) => write!(f, "Unsupported TTRV version: 0x{:04x}", v),
            TtError::TruncatedContainer(len) => write!(f, "Container truncated at {} bytes (min 56B)", len),
            TtError::LengthMismatch { expected, actual } => {
                write!(f, "Container length mismatch: expected {}B, got {}B", expected, actual)
            }
            TtError::PinRequired => write!(f, "Container is PIN-protected; user PIN required"),
            TtError::KeyDerivationFailed => write!(f, "Failed to derive cryptographic payload key"),
            TtError::AuthenticationFailed => {
                write!(f, "AES-256-GCM authentication failed (tampered header, payload, or wrong PIN)")
            }
            TtError::CompressionFailed(msg) => write!(f, "Zstandard compression failed: {}", msg),
            TtError::DecompressionFailed(msg) => write!(f, "Zstandard decompression failed: {}", msg),
            TtError::MalformedInnerStream(msg) => write!(f, "Malformed inner TTRV stream: {}", msg),
        }
    }
}

impl std::error::Error for TtError {}

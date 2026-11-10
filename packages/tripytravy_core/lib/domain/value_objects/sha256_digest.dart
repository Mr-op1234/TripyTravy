class Sha256Digest {
  final String hex;
  Sha256Digest(String raw) : hex = raw.trim().toLowerCase() {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hex)) {
      throw FormatException('Invalid 64-char SHA-256 hex digest: $raw');
    }
  }
  @override
  String toString() => hex;
}

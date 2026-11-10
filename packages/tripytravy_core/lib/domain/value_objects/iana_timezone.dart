class IanaTimezone {
  final String identifier;
  IanaTimezone(String raw) : identifier = raw.trim() {
    if (!isValid(identifier)) throw FormatException('Invalid IANA timezone: $raw');
  }
  static bool isValid(String tz) {
    final t = tz.trim();
    if (t == 'UTC' || t == 'Etc/UTC') return true;
    final p = t.split('/');
    return p.length >= 2 && p.every((s) => s.isNotEmpty);
  }
  @override
  String toString() => identifier;
}

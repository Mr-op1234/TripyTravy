class MoneyCurrency {
  final String currencyIso4217;
  final int minorUnits;
  MoneyCurrency({required String currencyIso4217, required this.minorUnits})
      : currencyIso4217 = currencyIso4217.trim().toUpperCase() {
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(this.currencyIso4217)) {
      throw FormatException('Invalid ISO 4217 currency code: $currencyIso4217');
    }
  }
}

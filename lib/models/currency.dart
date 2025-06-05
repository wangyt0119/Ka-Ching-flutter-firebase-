class Currency {
  final String code;
  final String name;
  final String symbol;
  double exchangeRate; // Made mutable to update with live rates

  Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.exchangeRate,
  });

  // Convert an amount from one currency to another using cross rates
  static double convert(double amount, Currency from, Currency to) {
    // If currencies are the same, return the original amount
    if (from.code == to.code) return amount;

    // Convert using cross rates
    // For example, to convert EUR to JPY:
    // EUR -> USD -> JPY
    // amount * (EUR/USD rate) * (JPY/USD rate)
    return amount * (to.exchangeRate / from.exchangeRate);
  }

  // Get a formatted string representation of the currency
  String format(double amount) {
    // Handle negative amounts
    String formattedValue = amount.abs().toStringAsFixed(2);

    // Add thousand separators for better readability
    final parts = formattedValue.split('.');
    final wholePart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );

    String result = parts.length > 1 ? '$wholePart.${parts[1]}' : wholePart;

    // Add currency symbol and negative sign if needed
    return '${symbol}${amount < 0 ? '-' : ''}$result';
  }

  // Get a string representation of the currency rate
  String getRateString() {
    return '1 $code = ${format(exchangeRate)} USD';
  }

  // Get a string representation of the currency rate relative to another currency
  String getRelativeRateString(Currency other) {
    if (code == other.code) return '1 $code = 1 ${other.code}';
    final rate = convert(1.0, this, other);
    return '1 $code = ${other.format(rate)}';
  }

  @override
  String toString() => '$name ($code)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Currency &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          name == other.name &&
          symbol == other.symbol &&
          exchangeRate == other.exchangeRate;

  @override
  int get hashCode =>
      code.hashCode ^
      name.hashCode ^
      symbol.hashCode ^
      exchangeRate.hashCode;
}

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

  // Convert an amount from one currency to another
  static double convert(double amount, Currency from, Currency to) {
    // Convert to USD first, then to target currency
    return amount * (from.exchangeRate / to.exchangeRate);
  }
}

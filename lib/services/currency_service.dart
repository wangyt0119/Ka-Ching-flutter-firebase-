import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/currency.dart';

class CurrencyService {
  static const String _selectedCurrencyKey = 'selected_currency';
  static const String _exchangeRatesKey = 'exchange_rates';
  static const String _lastUpdatedKey = 'exchange_rates_updated_at';

  // Common currencies with their initial rates
  static final List<Currency> _currencies = [
    Currency(code: 'USD', name: 'US Dollar', symbol: '\$', exchangeRate: 1.0),
    Currency(code: 'EUR', name: 'Euro', symbol: '€', exchangeRate: 0.85),
    Currency(
      code: 'GBP',
      name: 'British Pound',
      symbol: '£',
      exchangeRate: 0.73,
    ),
    Currency(
      code: 'JPY',
      name: 'Japanese Yen',
      symbol: '¥',
      exchangeRate: 110.33,
    ),
    Currency(
      code: 'CNY',
      name: 'Chinese Yuan',
      symbol: '¥',
      exchangeRate: 6.47,
    ),
    Currency(
      code: 'INR',
      name: 'Indian Rupee',
      symbol: '₹',
      exchangeRate: 74.38,
    ),
    Currency(
      code: 'MYR',
      name: 'Malaysian Ringgit',
      symbol: 'RM',
      exchangeRate: 4.20,
    ),
    Currency(
      code: 'SGD',
      name: 'Singapore Dollar',
      symbol: 'S\$',
      exchangeRate: 1.35,
    ),
    Currency(
      code: 'IDR',
      name: 'Indonesian Rupiah',
      symbol: 'Rp',
      exchangeRate: 14200,
    ),
  ];

  // Map to store live exchange rates
  Map<String, double> _exchangeRates = {};

  // Initialize the service with latest rates
  Future<void> initialize() async {
    await _loadExchangeRates();
    await _updateExchangeRatesIfNeeded();
  }

  // Load saved exchange rates from local storage
  Future<void> _loadExchangeRates() async {
    final prefs = await SharedPreferences.getInstance();
    final ratesJson = prefs.getString(_exchangeRatesKey);

    if (ratesJson != null) {
      final Map<String, dynamic> rates = jsonDecode(ratesJson);
      _exchangeRates = rates.map(
        (key, value) => MapEntry(key, value.toDouble()),
      );

      // Update currencies with saved rates
      for (var currency in _currencies) {
        if (_exchangeRates.containsKey(currency.code)) {
          currency.exchangeRate = _exchangeRates[currency.code]!;
        }
      }
    }
  }

  // Check if rates need updating (more than 12 hours old)
  Future<bool> _needsUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdated = prefs.getString(_lastUpdatedKey);

    if (lastUpdated == null) return true;

    final lastUpdateTime = DateTime.parse(lastUpdated);
    final now = DateTime.now();

    return now.difference(lastUpdateTime).inHours > 12;
  }

  // Update exchange rates from external API
  Future<void> _updateExchangeRatesIfNeeded() async {
    if (await _needsUpdate()) {
      try {
        // Free exchange rate API
        // Note: In a production app, you would use a paid API with better reliability
        final response = await http.get(
          Uri.parse('https://open.er-api.com/v6/latest/USD'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data['rates'] != null) {
            final Map<String, dynamic> newRates = data['rates'];
            _exchangeRates = newRates.map(
              (key, value) => MapEntry(key, value.toDouble()),
            );

            // Update currency exchange rates
            for (var currency in _currencies) {
              if (_exchangeRates.containsKey(currency.code)) {
                currency.exchangeRate = _exchangeRates[currency.code]!;
              }
            }

            // Save to local storage
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              _exchangeRatesKey,
              jsonEncode(_exchangeRates),
            );
            await prefs.setString(
              _lastUpdatedKey,
              DateTime.now().toIso8601String(),
            );
          }
        }
      } catch (e) {
        // If update fails, continue with existing rates
        print('Error updating exchange rates: $e');
      }
    }
  }

  // Get all available currencies with latest rates
  List<Currency> getAllCurrencies() {
    return _currencies;
  }

  // Get currency by code
  Currency? getCurrencyByCode(String code) {
    try {
      return _currencies.firstWhere((currency) => currency.code == code);
    } catch (e) {
      return null;
    }
  }

  // Get the default currency (USD)
  Currency getDefaultCurrency() {
    return _currencies.first;
  }

  // Save selected currency
  Future<void> setSelectedCurrency(Currency currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedCurrencyKey, currency.code);
  }

  // Get selected currency
  Future<Currency> getSelectedCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_selectedCurrencyKey);

    if (code != null) {
      final currency = getCurrencyByCode(code);
      if (currency != null) {
        return currency;
      }
    }

    return getDefaultCurrency();
  }

  // Force update exchange rates (useful for refresh button)
  Future<bool> forceUpdateRates() async {
    try {
      final response = await http.get(
        Uri.parse('https://open.er-api.com/v6/latest/USD'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['rates'] != null) {
          final Map<String, dynamic> newRates = data['rates'];
          _exchangeRates = newRates.map(
            (key, value) => MapEntry(key, value.toDouble()),
          );

          // Update currency exchange rates
          for (var currency in _currencies) {
            if (_exchangeRates.containsKey(currency.code)) {
              currency.exchangeRate = _exchangeRates[currency.code]!;
            }
          }

          // Save to local storage
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_exchangeRatesKey, jsonEncode(_exchangeRates));
          await prefs.setString(
            _lastUpdatedKey,
            DateTime.now().toIso8601String(),
          );

          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error updating exchange rates: $e');
      return false;
    }
  }

  // Convert currency from one to another
  static Future<double> convertCurrency(
    double amount,
    String fromCurrency,
    String toCurrency,
  ) async {
    final service = CurrencyService();
    await service.initialize();

    final from =
        service.getCurrencyByCode(fromCurrency) ?? service.getDefaultCurrency();
    final to =
        service.getCurrencyByCode(toCurrency) ?? service.getDefaultCurrency();

    return Currency.convert(amount, from, to);
  }

  // Format currency amount
  static String formatCurrency(double amount, String currencyCode) {
    final service = CurrencyService();
    final currency =
        service.getCurrencyByCode(currencyCode) ?? service.getDefaultCurrency();

    // Format based on currency - some currencies don't use decimals
    if (currency.code == 'JPY' || currency.code == 'IDR') {
      return '${currency.symbol}${amount.toInt()}';
    }

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
    return '${currency.symbol}${amount < 0 ? '-' : ''}$result';
  }

  // Get currency comparison with MYR
  static String getCurrencyComparison(String currencyCode) {
    final service = CurrencyService();
    final currency = service.getCurrencyByCode(currencyCode);
    final myr = service.getCurrencyByCode('MYR');

    if (currency == null || myr == null) return '';

    // Calculate the rate relative to MYR
    double rateToMYR = currency.exchangeRate / myr.exchangeRate;

    // Format the rate based on the currency
    String formattedRate;
    if (rateToMYR < 0.01) {
      formattedRate = rateToMYR.toStringAsFixed(4);
    } else if (rateToMYR < 1) {
      formattedRate = rateToMYR.toStringAsFixed(3);
    } else {
      formattedRate = rateToMYR.toStringAsFixed(2);
    }

    return '1 ${currency.code} = RM $formattedRate';
  }

  // Get all currency comparisons with MYR
  static List<String> getAllCurrencyComparisons() {
    final service = CurrencyService();
    return service
        .getAllCurrencies()
        .where((currency) => currency.code != 'MYR')
        .map((currency) => getCurrencyComparison(currency.code))
        .toList();
  }

  // Map of supported currencies with MYR comparison
  static Map<String, String> get supportedCurrencies => {
    'USD': 'US Dollar (1 USD = RM 4.20)',
    'EUR': 'Euro (1 EUR = RM 4.94)',
    'GBP': 'British Pound (1 GBP = RM 5.75)',
    'JPY': 'Japanese Yen (1 JPY = RM 0.038)',
    'CNY': 'Chinese Yuan (1 CNY = RM 0.65)',
    'INR': 'Indian Rupee (1 INR = RM 0.056)',
    'MYR': 'Malaysian Ringgit',
    'SGD': 'Singapore Dollar (1 SGD = RM 3.11)',
    'IDR': 'Indonesian Rupiah (1 IDR = RM 0.00030)',
  };
}

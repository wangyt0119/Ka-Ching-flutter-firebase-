import 'dart:convert';
import 'dart:math';
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

    if (lastUpdated == null) {
      print('🔄 No previous update found, update needed');
      return true;
    }

    final lastUpdateTime = DateTime.parse(lastUpdated);
    final now = DateTime.now();
    final hoursSinceUpdate = now.difference(lastUpdateTime).inHours;
    
    print('🔄 Last update was $hoursSinceUpdate hours ago');
    return hoursSinceUpdate > 12;
  }

  // Update exchange rates from external API with multiple fallbacks
  Future<void> _updateExchangeRatesIfNeeded() async {
    // Force update for testing
    print('🔄 Checking if exchange rates need updating...');
    final needsUpdate = await _needsUpdate();
    print('🔄 Needs update: $needsUpdate');
    
    if (needsUpdate) {
      print('🔄 Updating exchange rates...');

      // Try multiple APIs for better reliability
      final apis = [
        _fetchFromCurrencyAPI,
        _fetchFromExchangeRateAPI, // This one doesn't need an API key
        _fetchFromFixerIO,
        _fetchFromFreeCurrencyAPI,
      ];

      for (final apiCall in apis) {
        try {
          final rates = await apiCall();
          if (rates.isNotEmpty) {
            await _saveExchangeRates(rates);
            print('✅ Exchange rates updated successfully with ${rates.length} currencies');
            return;
          }
        } catch (e) {
          print('⚠️ API failed, trying next: $e');
          continue;
        }
      }

      print('❌ All APIs failed, using cached rates');
    } else {
      print('✅ Exchange rates are up to date');
    }
  }

  // API 1: CurrencyAPI (Most accurate)
  Future<Map<String, double>> _fetchFromCurrencyAPI() async {
    print('📡 Trying CurrencyAPI...');
    try {
      final response = await http.get(
        Uri.parse('https://api.currencyapi.com/v3/latest?apikey=cur_live_2fb8AIGRFzrQVlj5UIdsYRxBVs3PUtvgd1XoKqL1&base_currency=USD'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('📊 CurrencyAPI response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📊 CurrencyAPI response data: ${data.toString().substring(0, min(100, data.toString().length))}...');
        
        if (data['data'] != null) {
          final Map<String, double> rates = {};
          data['data'].forEach((key, value) {
            rates[key] = value['value'].toDouble();
          });
          print('✅ CurrencyAPI rates extracted: ${rates.length} currencies');
          return rates;
        } else {
          print('❌ CurrencyAPI data field is null');
        }
      } else {
        print('❌ CurrencyAPI failed with status: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ CurrencyAPI exception: $e');
    }
    throw Exception('CurrencyAPI failed');
  }

  // API 2: Fixer.io (Professional grade)
  Future<Map<String, double>> _fetchFromFixerIO() async {
    print('📡 Trying Fixer.io...');
    final response = await http.get(
      Uri.parse('http://data.fixer.io/api/latest?access_key=YOUR_API_KEY&base=USD'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['rates'] != null) {
        return Map<String, double>.from(
          data['rates'].map((key, value) => MapEntry(key, value.toDouble())),
        );
      }
    }
    throw Exception('Fixer.io failed');
  }

  // API 3: ExchangeRate-API (Current - reliable)
  Future<Map<String, double>> _fetchFromExchangeRateAPI() async {
    print('📡 Trying ExchangeRate-API...');
    final response = await http.get(
      Uri.parse('https://open.er-api.com/v6/latest/USD'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['rates'] != null) {
        return Map<String, double>.from(
          data['rates'].map((key, value) => MapEntry(key, value.toDouble())),
        );
      }
    }
    throw Exception('ExchangeRate-API failed');
  }

  // API 4: FreeCurrencyAPI (Backup)
  Future<Map<String, double>> _fetchFromFreeCurrencyAPI() async {
    print('📡 Trying FreeCurrencyAPI...');
    final response = await http.get(
      Uri.parse('https://api.freecurrencyapi.com/v1/latest?apikey=YOUR_API_KEY&base_currency=USD'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['data'] != null) {
        return Map<String, double>.from(
          data['data'].map((key, value) => MapEntry(key, value.toDouble())),
        );
      }
    }
    throw Exception('FreeCurrencyAPI failed');
  }

  // Save exchange rates to local storage and update currencies
  Future<void> _saveExchangeRates(Map<String, double> rates) async {
    _exchangeRates = rates;

    // Update currency exchange rates
    for (var currency in _currencies) {
      if (_exchangeRates.containsKey(currency.code)) {
        currency.exchangeRate = _exchangeRates[currency.code]!;
      }
    }

    // Save to local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_exchangeRatesKey, jsonEncode(_exchangeRates));
    await prefs.setString(_lastUpdatedKey, DateTime.now().toIso8601String());
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
    print('🔄 Force updating exchange rates...');
    
    // Clear cached rates for testing
    await clearCachedRates();

    // Try multiple APIs for better reliability
    final apis = [
      _fetchFromCurrencyAPI,
      _fetchFromExchangeRateAPI, // This one doesn't need an API key
      _fetchFromFixerIO,
      _fetchFromFreeCurrencyAPI,
    ];

    for (final apiCall in apis) {
      try {
        final rates = await apiCall();
        if (rates.isNotEmpty) {
          await _saveExchangeRates(rates);
          print('✅ Exchange rates force updated successfully with ${rates.length} currencies');
          return true;
        }
      } catch (e) {
        print('⚠️ API failed during force update, trying next: $e');
        continue;
      }
    }

    print('❌ All APIs failed during force update');
    return false;
  }

  // Get last update time for display
  Future<String> getLastUpdateTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdated = prefs.getString(_lastUpdatedKey);

    if (lastUpdated == null) return 'Never updated';

    final lastUpdateTime = DateTime.parse(lastUpdated);
    final now = DateTime.now();
    final difference = now.difference(lastUpdateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  // Check if rates are fresh (less than 1 hour old)
  Future<bool> areRatesFresh() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdated = prefs.getString(_lastUpdatedKey);

    if (lastUpdated == null) return false;

    final lastUpdateTime = DateTime.parse(lastUpdated);
    final now = DateTime.now();

    return now.difference(lastUpdateTime).inHours < 1;
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

  // For testing: Clear cached exchange rates
  Future<void> clearCachedRates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_exchangeRatesKey);
    await prefs.remove(_lastUpdatedKey);
    print('🧹 Cleared cached exchange rates');
  }
}

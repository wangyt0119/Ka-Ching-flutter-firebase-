import 'package:flutter/material.dart';
import '../models/currency.dart';
import '../services/currency_service.dart';

class CurrencyProvider extends ChangeNotifier {
  final CurrencyService _currencyService = CurrencyService();
  late Currency _selectedCurrency;
  bool _isLoading = true;
  bool _isUpdating = false;
  DateTime? _lastUpdated;
  String? _errorMessage;

  CurrencyProvider() {
    _selectedCurrency = _currencyService.getDefaultCurrency();
    _initCurrency();
  }

  Currency get selectedCurrency => _selectedCurrency;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  DateTime? get lastUpdated => _lastUpdated;
  String? get errorMessage => _errorMessage;
  List<Currency> get availableCurrencies => _currencyService.getAllCurrencies();

  Future<void> _initCurrency() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Initialize the service and load latest rates
      await _currencyService.initialize();
      _selectedCurrency = await _currencyService.getSelectedCurrency();
      _errorMessage = null;
    } catch (e) {
      // If there's an error, fallback to default
      _selectedCurrency = _currencyService.getDefaultCurrency();
      _errorMessage = 'Could not load currency data: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setSelectedCurrency(Currency currency) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _currencyService.setSelectedCurrency(currency);
      _selectedCurrency = currency;
      _errorMessage = null;
      _lastUpdated = DateTime.now();
    } catch (e) {
      _errorMessage = 'Could not change currency: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Format an amount according to the selected currency
  String formatAmount(double amount) {
    return _selectedCurrency.format(amount);
  }

  // Convert an amount from one currency to the selected currency
  double convertToSelectedCurrency(double amount, Currency fromCurrency) {
    return Currency.convert(amount, fromCurrency, _selectedCurrency);
  }

  // Convert an amount from one currency to another
  double convertCurrency(double amount, Currency fromCurrency, Currency toCurrency) {
    return Currency.convert(amount, fromCurrency, toCurrency);
  }

  // Get a string representation of the exchange rate between two currencies
  String getExchangeRateString(Currency fromCurrency, Currency toCurrency) {
    return fromCurrency.getRelativeRateString(toCurrency);
  }

  // Force update exchange rates from the API
  Future<bool> refreshExchangeRates() async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _currencyService.forceUpdateRates();
      if (success) {
        // Refresh the selected currency to get the updated rate
        _selectedCurrency = await _currencyService.getSelectedCurrency();
        _lastUpdated = DateTime.now();
      } else {
        _errorMessage = 'Could not update exchange rates';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Error refreshing exchange rates: ${e.toString()}';
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  // Get currency by code
  Currency? getCurrencyByCode(String code) {
    return _currencyService.getCurrencyByCode(code);
  }

  // Get currency comparison string
  String getCurrencyComparison(String currencyCode) {
    final currency = getCurrencyByCode(currencyCode);
    if (currency == null) return '';
    return currency.getRelativeRateString(_selectedCurrency);
  }

  // Get all currency comparisons
  List<String> getAllCurrencyComparisons() {
    return availableCurrencies
        .where((currency) => currency.code != _selectedCurrency.code)
        .map((currency) => currency.getRelativeRateString(_selectedCurrency))
        .toList();
  }
}

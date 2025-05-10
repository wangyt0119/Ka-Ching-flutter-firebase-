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
    } catch (e) {
      _errorMessage = 'Could not change currency: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Format an amount according to the selected currency
  String formatAmount(double amount) {
    // Format based on currency - some currencies don't use decimals
    if (_selectedCurrency.code == 'JPY' || _selectedCurrency.code == 'IDR') {
      return '${_selectedCurrency.symbol}${amount.toInt()}';
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
    return '${_selectedCurrency.symbol}${amount < 0 ? '-' : ''}$result';
  }

  // Convert an amount from one currency to the selected currency
  double convertToSelectedCurrency(double amount, Currency fromCurrency) {
    return Currency.convert(amount, fromCurrency, _selectedCurrency);
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

  double convertAmount(double amount) {
    // Assuming all stored amounts are in USD by default
    Currency usdCurrency =
        _currencyService.getCurrencyByCode('USD') ??
        Currency(
          code: 'USD',
          name: 'US Dollar',
          symbol: '\$',
          exchangeRate: 1.0,
        );
    return Currency.convert(amount, usdCurrency, _selectedCurrency);
  }
}

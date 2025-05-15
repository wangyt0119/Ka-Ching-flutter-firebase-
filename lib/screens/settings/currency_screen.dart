import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/currency.dart';
import '../../providers/currency_provider.dart';
import '../../theme/app_theme.dart';

class CurrencyScreen extends StatelessWidget {
  const CurrencyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final currencies = currencyProvider.availableCurrencies;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Select Currency'),
        actions: [
          // Refresh rates button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Update exchange rates',
            onPressed:
                currencyProvider.isUpdating
                    ? null
                    : () async {
                      final success =
                          await currencyProvider.refreshExchangeRates();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Exchange rates updated successfully'
                                  : 'Failed to update exchange rates',
                            ),
                            backgroundColor:
                                success
                                    ? AppTheme.positiveAmount
                                    : AppTheme.negativeAmount,
                          ),
                        );
                      }
                    },
          ),
        ],
      ),
      body: Column(
        children: [
          // Info card showing last update time
          if (currencyProvider.lastUpdated != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: AppTheme.secondaryLightColor.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppTheme.secondaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Exchange rates last updated on: ${DateFormat('MMM d, yyyy HH:mm').format(currencyProvider.lastUpdated!)}',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Error message if any
          if (currencyProvider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: AppTheme.errorColor.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currencyProvider.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Loading indicator when refreshing rates
          if (currencyProvider.isUpdating)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(child: CircularProgressIndicator()),
            ),

          // Currency list
          Expanded(
            child:
                currencyProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      itemCount: currencies.length,
                      itemBuilder: (context, index) {
                        final currency = currencies[index];
                        final isSelected =
                            currency.code ==
                            currencyProvider.selectedCurrency.code;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.secondaryColor.withOpacity(0.3),
                            child: Text(
                              currency.symbol,
                              style: TextStyle(
                                color:
                                    isSelected
                                        ? Colors.white
                                        : AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(currency.name),
                          subtitle: Row(
                            children: [
                              Text(currency.code),
                              const SizedBox(width: 8),
                              Text(
                                '(1 USD = ${currency.exchangeRate.toStringAsFixed(4)} ${currency.code})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          trailing:
                              isSelected
                                  ? const Icon(
                                    Icons.check_circle,
                                    color: AppTheme.primaryColor,
                                  )
                                  : null,
                          onTap: () async {
                            await currencyProvider.setSelectedCurrency(
                              currency,
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

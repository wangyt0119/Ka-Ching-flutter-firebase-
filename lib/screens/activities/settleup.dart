import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';
import '../../theme/app_theme.dart';

class SettleUpButton extends StatelessWidget {
  final Map<String, dynamic> activity;
  final String activityId;
  final String? ownerId;
  final Function refreshActivity;

  const SettleUpButton({
    Key? key,
    required this.activity,
    required this.activityId,
    required this.ownerId,
    required this.refreshActivity,
  }) : super(key: key);

  void _showSettleUpDialog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    final userEmail = user?.email;
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    
    // Get balances by currency from activity data
    final balancesByCurrency = activity['balances_by_currency'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{};
    
    // Helper function to get display name
    String getDisplayName(String key) {
      // Check if it's an email and we have a name for it
      if (activity['members'] != null) {
        for (var member in activity['members']) {
          if (member is Map) {
            if (member['email'] == key || member['id'] == key) {
              return member['name'] ?? key;
            }
          }
        }
      }
      
      // If it looks like an email, extract the part before @
      if (key.contains('@')) {
        return key.split('@')[0];
      }
      
      // Fallback to the key itself
      return key;
    }
    
    // Robust identity matching
    final uid = userId ?? '';
    final email = userEmail ?? '';
    bool isSelf(String key) => key == uid || key == email;
    
    // Prepare lists for the dialog
    final Map<String, List<Widget>> currencyBalanceWidgets = {};
    
    // Process each currency's balances
    balancesByCurrency.forEach((currency, balancesForCurrency) {
      if (balancesForCurrency is! Map) return;
      
      final List<Widget> peopleWhoOweYou = [];
      final List<Widget> peopleYouOwe = [];
      
      balancesForCurrency.forEach((key, value) {
        if (isSelf(key)) return; // Skip self
        
        final double amount = (value as num).toDouble();
        final displayName = getDisplayName(key);
        final currencyObj = currencyProvider.getCurrencyByCode(currency) ?? 
                           currencyProvider.selectedCurrency;
        
        if (amount < 0) {
          // They owe you
          peopleWhoOweYou.add(
            ListTile(
              title: Text(displayName),
              subtitle: Text(
                '$displayName owes you ${currencyObj.symbol}${amount.abs().toStringAsFixed(2)} (${currencyObj.code})',
                style: const TextStyle(color: AppTheme.positiveAmount),
              ),
              onTap: () {
                Navigator.pop(context);
                _showSettlementAmountDialog(
                  context,
                  displayName,
                  key,
                  -amount, // Negative because they owe you
                  currencyProvider,
                  refreshActivity,
                  currency,
                );
              },
            ),
          );
        } else if (amount > 0) {
          // You owe them
          peopleYouOwe.add(
            ListTile(
              title: Text(displayName),
              subtitle: Text(
                'You owe $displayName ${currencyObj.symbol}${amount.toStringAsFixed(2)} (${currencyObj.code})',
                style: const TextStyle(color: AppTheme.negativeAmount),
              ),
              onTap: () {
                Navigator.pop(context);
                _showSettlementAmountDialog(
                  context,
                  displayName,
                  key,
                  amount, // Positive because you owe them
                  currencyProvider,
                  refreshActivity,
                  currency,
                );
              },
            ),
          );
        }
      });
      
      // Only add currency section if there are balances to show
      if (peopleWhoOweYou.isNotEmpty || peopleYouOwe.isNotEmpty) {
        currencyBalanceWidgets[currency] = [
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Text(
              '$currency Balances:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ...peopleYouOwe,
          ...peopleWhoOweYou,
        ];
      }
    });
    
    if (currencyBalanceWidgets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No debts to settle in this activity')),
      );
      return;
    }
    
    // Show the dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settle Up'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select who you want to settle up with:'),
                
                // Display balances for each currency
                ...currencyBalanceWidgets.entries.expand((entry) => entry.value),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSettlementAmountDialog(
    BuildContext context,
    String displayName,
    String personId,
    double balance,
    CurrencyProvider currencyProvider,
    Function refreshActivity,
    String currencyCode,
  ) {
    final TextEditingController amountController = TextEditingController(
      text: balance.abs().toStringAsFixed(2)
    );
    final isPositive = balance >= 0;
    final maxAmount = balance.abs();
    final currencyObj = currencyProvider.getCurrencyByCode(currencyCode) ?? 
                       currencyProvider.selectedCurrency;
    final currencySymbol = currencyObj.symbol;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Settlement Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPositive 
                  ? 'You owe $displayName $currencySymbol${maxAmount.toStringAsFixed(2)} ($currencyCode)'
                  : '$displayName owes you $currencySymbol${maxAmount.toStringAsFixed(2)} ($currencyCode)'
            ),
            const SizedBox(height: 16),
            const Text('How much would you like to settle?'),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: currencySymbol,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0.0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a positive amount')),
                );
                return;
              }
              if (amount > maxAmount) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Amount cannot exceed ${currencyObj.symbol}${maxAmount.toStringAsFixed(2)}')),
                );
                return;
              }
              Navigator.pop(context);
              _createSettlementTransaction(
                context,
                personId,
                displayName,
                isPositive ? amount : -amount,
                refreshActivity,
                currencyCode,
              );
            },
            child: const Text('Settle'),
          ),
        ],
      ),
    );
  }

  Future<void> _createSettlementTransaction(
    BuildContext context,
    String personId,
    String personName,
    double balance,
    Function refreshActivity,
    String currencyCode,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      final currencyObj = currencyProvider.getCurrencyByCode(currencyCode) ?? 
                         currencyProvider.selectedCurrency;
      
      // Determine who is paying whom
      final isUserPaying = balance > 0; // If balance is positive, user owes the other person
      final settlementFrom = isUserPaying ? user.email : personId;
      final settlementTo = isUserPaying ? personId : user.email;
      
      // Create the settlement transaction
      final settlement = {
        'title': 'Settlement',
        'amount': balance.abs(),
        'currency': currencyCode,
        'date': DateTime.now().toIso8601String(),
        'timestamp': FieldValue.serverTimestamp(),
        'description': isUserPaying 
            ? 'You paid ${personName}'
            : '${personName} paid you',
        'category': 'Settlement',
        'paid_by': isUserPaying ? user.email : personId,
        'paid_by_id': isUserPaying ? user.uid : '',
        'participants': [user.email, personId],
        'split': 'settlement',
        'is_settlement': true,
        'settlement_from': settlementFrom,
        'settlement_to': settlementTo,
      };
      
      // Get the owner ID for the activity
      final ownerIdForQuery = ownerId ?? user.uid;
      
      // Reference to the activity
      final activityRef = FirebaseFirestore.instance
          .collection('users')
          .doc(ownerIdForQuery)
          .collection('activities')
          .doc(activityId);
      
      // Add the settlement transaction
      await activityRef.collection('transactions').add(settlement);
      
      // Get current activity data
      final activityDoc = await activityRef.get();
      final activityData = activityDoc.data() ?? {};
      
      // Get or initialize the currency-specific balances
      Map<String, Map<String, dynamic>> balancesByCurrency = {};
      
      if (activityData.containsKey('balances_by_currency')) {
        final rawBalancesByCurrency = activityData['balances_by_currency'] as Map<String, dynamic>?;
        if (rawBalancesByCurrency != null) {
          rawBalancesByCurrency.forEach((currency, balanceData) {
            balancesByCurrency[currency] = Map<String, dynamic>.from(balanceData);
          });
        }
      }
      
      // Recalculate all balances
      await _recalculateBalances(
        ownerIdForQuery,
        activityId,
        balancesByCurrency,
      );
      
      // Refresh the activity data
      refreshActivity();
      
      // Use context.mounted to check if the context is still valid
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settlement of ${currencyObj.symbol}${balance.abs().toStringAsFixed(2)} recorded')),
        );
      }
    } catch (e) {
      debugPrint('Error creating settlement: $e');
      // Use context.mounted to check if the context is still valid
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _recalculateBalances(
    String ownerId,
    String activityId,
    Map<String, Map<String, dynamic>> balancesByCurrency,
  ) async {
    // Clear existing balances
    balancesByCurrency.clear();
    
    // Get all transactions
    final transactionsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(ownerId)
        .collection('activities')
        .doc(activityId)
        .collection('transactions')
        .get();
    
    // Process each transaction
    for (var doc in transactionsSnapshot.docs) {
      final transaction = doc.data();
      final amount = transaction['amount'] ?? 0.0;
      final currency = transaction['currency'] ?? 'MYR';
      final paidBy = transaction['paid_by'] ?? '';
      final paidById = transaction['paid_by_id'] ?? '';
      
      // Initialize currency in balancesByCurrency if not exists
      if (!balancesByCurrency.containsKey(currency)) {
        balancesByCurrency[currency] = {};
      }
      
      // Handle settlement transactions
      if (transaction['is_settlement'] == true) {
        final settlementFrom = transaction['settlement_from'] ?? '';
        final settlementTo = transaction['settlement_to'] ?? '';
        
        if (settlementFrom.isNotEmpty && settlementTo.isNotEmpty) {
          // Adjust balances for settlement
          balancesByCurrency[currency]![settlementFrom] = 
              (balancesByCurrency[currency]![settlementFrom] ?? 0.0) + amount;
          balancesByCurrency[currency]![settlementTo] = 
              (balancesByCurrency[currency]![settlementTo] ?? 0.0) - amount;
        }
        continue;
      }
      
      // Handle regular transactions
      final split = transaction['split'] ?? 'equally';
      final participants = List<String>.from(transaction['participants'] ?? []);
      
      if (participants.isEmpty) continue;
      
      // Determine who paid
      String actualPayer = paidById.isNotEmpty ? paidById : paidBy;
      
      // Add the full amount to the payer's balance
      balancesByCurrency[currency]![actualPayer] = 
          (balancesByCurrency[currency]![actualPayer] ?? 0.0) + amount;
      
      // Subtract each participant's share
      if (split == 'equally') {
        final share = amount / participants.length;
        for (var participant in participants) {
          balancesByCurrency[currency]![participant] = 
              (balancesByCurrency[currency]![participant] ?? 0.0) - share;
        }
      } else if (split == 'unequally' || split == 'percentage') {
        final customAmounts = transaction['custom_amounts'] ?? {};
        for (var entry in customAmounts.entries) {
          final participantId = entry.key;
          final participantAmount = entry.value;
          balancesByCurrency[currency]![participantId] = 
              (balancesByCurrency[currency]![participantId] ?? 0.0) - participantAmount;
        }
      }
    }
    
    // Round small values to zero for each currency
    balancesByCurrency.forEach((currency, currencyBalances) {
      currencyBalances.removeWhere((key, value) => (value as num).abs() < 0.01);
    });
    
    // Update the activity document with the new balances
    await FirebaseFirestore.instance
        .collection('users')
        .doc(ownerId)
        .collection('activities')
        .doc(activityId)
        .update({
          'balances_by_currency': balancesByCurrency,
        });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF5A9C1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () => _showSettleUpDialog(context),
        child: const Text(
          'Settle Up',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}








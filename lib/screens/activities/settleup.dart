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
    final selectedCurrency = currencyProvider.selectedCurrency;
    
    // Recalculate balances in memory using activity data
    Map<String, double> balances = {};
    Map<String, String> idToName = {};
    Map<String, String> emailToName = {};
    
    // Extract members and their IDs/names
    if (activity['members'] != null) {
      for (var member in activity['members']) {
        if (member is Map) {
          final id = member['id'] ?? '';
          final email = member['email'] ?? '';
          final name = member['name'] ?? email;
          
          if (id.isNotEmpty) balances[id] = 0.0;
          if (email.isNotEmpty) balances[email] = 0.0;
          
          if (id.isNotEmpty) idToName[id] = name;
          if (email.isNotEmpty) emailToName[email] = name;
        }
      }
    }
    
    // Get transactions to calculate balances
    final ownerIdForQuery = ownerId ?? userId;
    final transactionsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(ownerIdForQuery)
        .collection('activities')
        .doc(activityId)
        .collection('transactions')
        .get();
    
    // Calculate balances from transactions
    for (var doc in transactionsSnapshot.docs) {
      final transaction = doc.data();
      final amount = transaction['amount'] ?? 0.0;
      final paidBy = transaction['paid_by'] ?? '';
      final paidById = transaction['paid_by_id'] ?? '';
      
      // Handle settlement transactions
      if (transaction['is_settlement'] == true) {
        final settlementFrom = transaction['settlement_from'] ?? '';
        final settlementTo = transaction['settlement_to'] ?? '';
        final settlementAmount = amount;
        
        if (settlementFrom.isNotEmpty && settlementTo.isNotEmpty) {
          // Adjust balances for settlement
          balances[settlementFrom] = (balances[settlementFrom] ?? 0.0) + settlementAmount;
          balances[settlementTo] = (balances[settlementTo] ?? 0.0) - settlementAmount;
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
      balances[actualPayer] = (balances[actualPayer] ?? 0.0) + amount;
      
      // Subtract each participant's share
      if (split == 'equally') {
        final share = amount / participants.length;
        for (var participant in participants) {
          balances[participant] = (balances[participant] ?? 0.0) - share;
        }
      } else if (split == 'unequally' || split == 'percentage') {
        final customAmounts = transaction['custom_amounts'] ?? {};
        for (var entry in customAmounts.entries) {
          final participantId = entry.key;
          final participantAmount = entry.value;
          balances[participantId] = (balances[participantId] ?? 0.0) - participantAmount;
        }
      }
    }
    
    // Filter out balances that are close to zero
    balances.removeWhere((key, value) => value.abs() < 0.01);
    
    // Prepare lists for the dialog
    final currentUserId = userId ?? '';
    final peopleWhoOweYou = <MapEntry<String, double>>[];
    final peopleYouOwe = <MapEntry<String, double>>[];
    
    for (var entry in balances.entries) {
      // Skip the current user
      if (entry.key == currentUserId || entry.key == userEmail) continue;
      
      if (entry.value < 0) {
        // Negative balance means they owe you
        peopleWhoOweYou.add(MapEntry(entry.key, entry.value.abs()));
      } else if (entry.value > 0) {
        // Positive balance means you owe them
        peopleYouOwe.add(MapEntry(entry.key, entry.value));
      }
    }
    
    // Sort by amount (highest first)
    peopleWhoOweYou.sort((a, b) => b.value.compareTo(a.value));
    peopleYouOwe.sort((a, b) => b.value.compareTo(a.value));
    
    if (peopleWhoOweYou.isEmpty && peopleYouOwe.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No debts to settle in this activity')),
      );
      return;
    }
    
    // Helper function to get display name
    String getDisplayName(String key) {
      // Check if it's an email and we have a name for it
      if (emailToName.containsKey(key)) {
        return emailToName[key]!;
      }
      // Check if it's an ID and we have a name for it
      if (idToName.containsKey(key)) {
        return idToName[key]!;
      }
      // If it looks like an email, extract the part before @
      if (key.contains('@')) {
        return key.split('@')[0];
      }
      // Fallback to the key itself
      return key;
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
                const SizedBox(height: 16),
                
                // People who owe you
                if (peopleWhoOweYou.isNotEmpty) ...[
                  const Text(
                    'They owe you:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...peopleWhoOweYou.map((entry) {
                    final displayName = getDisplayName(entry.key);
                    return ListTile(
                      title: Text(displayName),
                      subtitle: Text(
                        '$displayName owes you ${currencyProvider.formatAmount(entry.value)} (${currencyProvider.selectedCurrency.code})',
                        style: const TextStyle(color: AppTheme.positiveAmount),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showSettlementAmountDialog(
                          context,
                          displayName,
                          entry.key,
                          -entry.value, // Negative because they owe you
                          currencyProvider,
                          refreshActivity,
                        );
                      },
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                ],
                
                // People you owe
                if (peopleYouOwe.isNotEmpty) ...[
                  const Text(
                    'You owe:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...peopleYouOwe.map((entry) {
                    final displayName = getDisplayName(entry.key);
                    return ListTile(
                      title: Text(displayName),
                      subtitle: Text(
                        'You owe $displayName ${currencyProvider.formatAmount(entry.value)} (${currencyProvider.selectedCurrency.code})',
                        style: const TextStyle(color: AppTheme.negativeAmount),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showSettlementAmountDialog(
                          context,
                          displayName,
                          entry.key,
                          entry.value, // Positive because you owe them
                          currencyProvider,
                          refreshActivity,
                        );
                      },
                    );
                  }).toList(),
                ],
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
  ) {
    final TextEditingController amountController = TextEditingController(
      text: balance.abs().toStringAsFixed(2)
    );
    final isPositive = balance >= 0;
    final maxAmount = balance.abs();
    final currencySymbol = currencyProvider.selectedCurrency.symbol;
    
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
                  ? 'You owe $displayName $currencySymbol${maxAmount.toStringAsFixed(2)}'
                  : '$displayName owes you $currencySymbol${maxAmount.toStringAsFixed(2)}'
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
                  SnackBar(content: Text('Amount cannot exceed ${currencyProvider.formatAmount(maxAmount)}')),
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
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      
      // Get the activity's original currency
      final activityCurrency = activity['currency'] ?? 'USD';
      final activityCurrencyObj = currencyProvider.getCurrencyByCode(activityCurrency) ??
                                 currencyProvider.selectedCurrency;
      
      // Convert the settlement amount to the activity's currency
      final settlementAmountInActivityCurrency = currencyProvider.convertCurrency(
        balance.abs(),
        currencyProvider.selectedCurrency,
        activityCurrencyObj
      );
      
      // Create a settlement transaction in the selected activity
      final isPositive = balance >= 0;
      
      // Use the actual user ID instead of "You" for consistency with balance calculations
      final currentUserKey = user.uid;
      
      final settlement = {
        'title': isPositive ? 'You settled debt with $personName' : '$personName settled debt with you',
        'amount': settlementAmountInActivityCurrency,
        'currency': activityCurrency,
        'date': DateTime.now().toString().split(' ')[0],
        'description': 'Settlement transaction',
        'paid_by': isPositive ? currentUserKey : personId,
        'paid_by_id': isPositive ? currentUserKey : personId,
        'split': 'settlement', // Use a special split type for settlements
        'participants': [personId], // Only the other person participates in settlement
        'settlement_amount': settlementAmountInActivityCurrency,
        'settlement_from': isPositive ? currentUserKey : personId,
        'settlement_to': isPositive ? personId : currentUserKey,
        'is_settlement': true,
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      final ownerIdForQuery = ownerId ?? user.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerIdForQuery)
          .collection('activities')
          .doc(activityId)
          .collection('transactions')
          .add(settlement);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settlement recorded successfully')),
      );
      
      // Refresh the activity data
      refreshActivity();
    } catch (e) {
      debugPrint('Error creating settlement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating settlement: $e')),
      );
    }
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






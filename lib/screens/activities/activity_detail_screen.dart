import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../transactions/add_expense_screen.dart';
import 'edit_activity_screen.dart';
import '../transactions/transaction_detail_screen.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';
import 'total_spent.dart';

// Helper class for settlement options
class SettlementOption {
  final String name;
  final double balance;
  final String displayText;
  
  SettlementOption({
    required this.name,
    required this.balance,
    required this.displayText,
  });
}

class ActivityDetailsScreen extends StatefulWidget {
  final String activityId;
  final String? ownerId;
  final String title;

  const ActivityDetailsScreen({
    super.key, 
    required this.activityId, 
    required this.title, 
    this.ownerId,
  });

  @override
  State<ActivityDetailsScreen> createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _activity;
  List<Map<String, dynamic>> _transactions = [];
  bool _isCreator = true;

  @override
  void initState() {
    super.initState();
    _loadActivityData();
  }

  Future<void> _loadActivityData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Determine if user is creator or participant
        _isCreator = widget.ownerId == null;
        
        // Reference to the activity document
        DocumentReference activityRef;
        
        if (_isCreator) {
          // User is the creator
          activityRef = _firestore
              .collection('users')
              .doc(user.uid)
              .collection('activities')
              .doc(widget.activityId);
        } else {
          // User is a participant
          activityRef = _firestore
              .collection('users')
              .doc(widget.ownerId)
              .collection('activities')
              .doc(widget.activityId);
        }

        // Load activity details
        final activityDoc = await activityRef.get();

        if (activityDoc.exists) {
          final activityData = activityDoc.data() as Map<String, dynamic>;
          activityData['id'] = activityDoc.id;

          // Load transactions for this activity
          final transactionsSnapshot = await activityRef
              .collection('transactions')
              .orderBy('timestamp', descending: true)
              .get();

          final transactions = transactionsSnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          setState(() {
            _activity = activityData;
            _transactions = transactions;
            _isLoading = false;
          });

          // Recalculate totals after loading data (but don't reload data again)
          await _recalculateActivityTotals(skipDataReload: true);
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading activity data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final user = FirebaseAuth.instance.currentUser;
    final paidById = transaction['paid_by_id'];
    final paidBy = transaction['paid_by'] ?? '';
    
    // Check if current user is the payer
    final isCurrentUserPayer = paidById == user?.uid || 
                              paidBy == user?.displayName || 
                              paidBy == user?.email;
    
    // Display logic
    final amount = transaction['amount']?.toDouble() ?? 0.0;
    final date = transaction['date'] ?? '';
    final category = transaction['category'] ?? 'Other';

    // Get icon based on category
    IconData categoryIcon;
    switch (category) {
      case 'Food':
        categoryIcon = Icons.restaurant;
        break;
      case 'Beverage':
        categoryIcon = Icons.local_drink;
        break;
      case 'Entertainment':
        categoryIcon = Icons.movie;
        break;
      case 'Transportation':
        categoryIcon = Icons.directions_car;
        break;
      case 'Shopping':
        categoryIcon = Icons.shopping_bag;
        break;
      case 'Travel':
        categoryIcon = Icons.flight;
        break;
      case 'Utilities':
        categoryIcon = Icons.power;
        break;
      default:
        categoryIcon = Icons.category;
    }

    final originalCurrency = transaction['currency'] ?? 'USD';
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final fromCurrency = currencyProvider.availableCurrencies.firstWhere(
      (c) => c.code == originalCurrency,
      orElse: () => currencyProvider.selectedCurrency,
    );
    final converted = currencyProvider.convertToSelectedCurrency(amount, fromCurrency);
    final displayAmount = currencyProvider.formatAmount(converted);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionDetailScreen(
                transactionId: transaction['id'],
                activityId: widget.activityId,
                ownerId: widget.ownerId,
              ),
            ),
          );

          if (result == true) {
            await _loadActivityData();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  categoryIcon,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction['title'] ?? 'Untitled',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Paid by ${isCurrentUserPayer ? 'You' : paidBy}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Original currency (bigger)
                  Text(
                    '$originalCurrency ${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  // Converted currency (smaller)
                  Text(
                    displayAmount,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to map userId/email to display name
  Map<String, String> _buildIdToNameMap() {
    final Map<String, String> idToName = {};
    if (_activity != null && _activity!['members'] != null) {
      for (var member in _activity!['members']) {
        if (member is Map) {
          final id = member['id'] ?? member['email'] ?? member['name'];
          final name = member['name'] ?? member['email'] ?? member['id'];
          idToName[id] = name;
          if (member['email'] != null) idToName[member['email']] = name;
        }
      }
    }
    return idToName;
  }

  // 1. Helper to get all possible keys for a user
  Set<String> _getUserKeys(User? user) {
    final keys = <String>{};
    if (user != null) {
      if (user.uid.isNotEmpty) keys.add(user.uid);
      if (user.email != null && user.email!.isNotEmpty) keys.add(user.email!);
    }
    keys.add('You');
    return keys;
  }

  // Add a method to show who owes you money
  Widget _buildBalancesCard() {
    if (_activity == null) {
      return const SizedBox();
    }
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    final userEmail = user?.email;
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final selectedCurrency = currencyProvider.selectedCurrency;
    final currencySymbol = selectedCurrency.symbol;
    // Recalculate balances in memory using original transaction data
    Map<String, double> balances = {};
    if (_activity != null && _activity!['members'] != null) {
      for (var member in _activity!['members']) {
        final id = member is Map ? (member['id'] ?? member['email'] ?? member['name']) : member;
        balances[id] = 0.0;
      }
    }
    for (var transaction in _transactions) {
      final paidBy = transaction['paid_by'] ?? '';
      final originalAmount = transaction['amount']?.toDouble() ?? 0.0;
      final originalCurrency = transaction['currency'] ?? 'USD';
      final fromCurrency = currencyProvider.availableCurrencies.firstWhere(
        (c) => c.code == originalCurrency,
        orElse: () => selectedCurrency,
      );
      final amount = currencyProvider.convertToSelectedCurrency(originalAmount, fromCurrency);
      final split = transaction['split'] ?? 'equally';
      final participants = List<String>.from(transaction['participants'] ?? []);
      // Handle settlement transactions
      if (transaction['is_settlement'] == true) {
        final settlementFrom = transaction['settlement_from'] ?? '';
        final settlementTo = transaction['settlement_to'] ?? '';
        final settlementAmount = amount;
        if (settlementFrom.isNotEmpty && settlementTo.isNotEmpty) {
          balances[settlementFrom] = (balances[settlementFrom] ?? 0.0) + settlementAmount;
          balances[settlementTo] = (balances[settlementTo] ?? 0.0) - settlementAmount;
        }
        continue;
      }
      if (split == 'equally' && participants.isNotEmpty) {
        final sharePerPerson = amount / participants.length;
        balances[paidBy] = (balances[paidBy] ?? 0.0) + amount;
        for (var participant in participants) {
          balances[participant] = (balances[participant] ?? 0.0) - sharePerPerson;
        }
      } else if (split == 'unequally' && transaction['shares'] != null) {
        final shares = Map<String, dynamic>.from(transaction['shares']);
        balances[paidBy] = (balances[paidBy] ?? 0.0) + amount;
        for (var participant in participants) {
          final shareOriginal = shares[participant]?.toDouble() ?? 0.0;
          final shareConverted = currencyProvider.convertToSelectedCurrency(shareOriginal, fromCurrency);
          balances[participant] = (balances[participant] ?? 0.0) - shareConverted;
        }
      } else if (split == 'percentage' && transaction['shares'] != null) {
        final shares = Map<String, dynamic>.from(transaction['shares']);
        balances[paidBy] = (balances[paidBy] ?? 0.0) + amount;
        for (var participant in participants) {
          final percentage = shares[participant]?.toDouble() ?? 0.0;
          final shareOriginal = originalAmount * percentage / 100;
          final shareConverted = currencyProvider.convertToSelectedCurrency(shareOriginal, fromCurrency);
          balances[participant] = (balances[participant] ?? 0.0) - shareConverted;
        }
      }
    }
    // After all balances are calculated, round balances close to zero to zero
    balances.updateAll((key, value) => (value.abs() < 0.01) ? 0.0 : value);
    double currentUserBalance = 0.0;
    for (String key in _getUserKeys(user)) {
      if (balances.containsKey(key)) {
        currentUserBalance += balances[key] ?? 0.0;
        balances.remove(key);
      }
    }
    // At this point, balances contains only other users
    // The sum of all balances (including currentUserBalance) should be zero
    // Display logic:
    final idToName = _buildIdToNameMap();
    final peopleWhoOweYou = currentUserBalance > 0
        ? balances.entries.where((entry) => entry.value < -0.01).toList()
        : [];
    final peopleYouOwe = currentUserBalance < 0
        ? balances.entries.where((entry) => entry.value > 0.01).toList()
        : [];

    // Determine the owner ID
    final ownerId = widget.ownerId ?? FirebaseAuth.instance.currentUser?.uid;

    // Filter out the owner from the peopleWhoOweYou and peopleYouOwe lists for settle up dialog
    final filteredPeopleWhoOweYouCard = peopleWhoOweYou.where((entry) => entry.key != ownerId && entry.value.abs() > 0.01).toList();
    final filteredPeopleYouOweCard = peopleYouOwe.where((entry) => entry.key != ownerId && entry.value.abs() > 0.01).toList();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Balances',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            // Your overall balance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your balance:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${currentUserBalance >= 0 ? '+' : ''}${currencyProvider.formatAmount(currentUserBalance)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: currentUserBalance >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // People who owe you money
            if (filteredPeopleWhoOweYouCard.isNotEmpty) ...[
              const Text(
                'People who owe you:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...filteredPeopleWhoOweYouCard.map((entry) {
                final rawKey = entry.key;
                final displayName = idToName[rawKey] ?? rawKey; // fallback to rawKey if not found
                final amount = entry.value.abs();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(displayName),
                      Text(
                        currencyProvider.formatAmount(amount),
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const Divider(height: 16),
            ],
            // People you owe money to
            if (filteredPeopleYouOweCard.isNotEmpty) ...[
              const Text(
                'You owe:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...filteredPeopleYouOweCard.map((entry) {
                final rawKey = entry.key;
                final displayName = idToName[rawKey] ?? rawKey; // fallback to rawKey if not found
                final amount = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(displayName),
                      Text(
                        currencyProvider.formatAmount(amount),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const Divider(height: 16),
            ],
            if (filteredPeopleWhoOweYouCard.isEmpty && filteredPeopleYouOweCard.isEmpty) ...[
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'All settled!',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Add settle up button
            if (filteredPeopleWhoOweYouCard.isNotEmpty || filteredPeopleYouOweCard.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5A9C1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _showSettleUpDialog,
                  child: const Text('Settle Up'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Add a method to show the settle up dialog
  void _showSettleUpDialog() {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    final userEmail = user?.email;
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final selectedCurrency = currencyProvider.selectedCurrency;
    final currencySymbol = selectedCurrency.symbol;
    // Recalculate balances in memory using original transaction data
    Map<String, double> balances = {};
    if (_activity != null && _activity!['members'] != null) {
      for (var member in _activity!['members']) {
        final id = member is Map ? (member['id'] ?? member['email'] ?? member['name']) : member;
        balances[id] = 0.0;
      }
    }
    for (var transaction in _transactions) {
      final paidBy = transaction['paid_by'] ?? '';
      final originalAmount = transaction['amount']?.toDouble() ?? 0.0;
      final originalCurrency = transaction['currency'] ?? 'USD';
      final fromCurrency = currencyProvider.availableCurrencies.firstWhere(
        (c) => c.code == originalCurrency,
        orElse: () => selectedCurrency,
      );
      final amount = currencyProvider.convertToSelectedCurrency(originalAmount, fromCurrency);
      final split = transaction['split'] ?? 'equally';
      final participants = List<String>.from(transaction['participants'] ?? []);
      // Handle settlement transactions
      if (transaction['is_settlement'] == true) {
        final settlementFrom = transaction['settlement_from'] ?? '';
        final settlementTo = transaction['settlement_to'] ?? '';
        final settlementAmount = amount;

        // Apply settlement: reduce debt between parties
        // When someone pays to settle debt, their balance increases (less negative or more positive)
        // and the receiver's balance decreases (less positive or more negative)
        if (settlementFrom.isNotEmpty && settlementTo.isNotEmpty) {
          // Handle both old format ("You") and new format (user ID)
          String actualSettlementFrom = settlementFrom;
          String actualSettlementTo = settlementTo;

          // Convert "You" to actual user ID for consistency
          if (settlementFrom == 'You') {
            actualSettlementFrom = userId ?? userEmail ?? 'You';
          }
          if (settlementTo == 'You') {
            actualSettlementTo = userId ?? userEmail ?? 'You';
          }

          balances[actualSettlementFrom] = (balances[actualSettlementFrom] ?? 0.0) + settlementAmount;
          balances[actualSettlementTo] = (balances[actualSettlementTo] ?? 0.0) - settlementAmount;
        }
        continue;
      }
      if (split == 'equally' && participants.isNotEmpty) {
        final sharePerPerson = amount / participants.length;
        balances[paidBy] = (balances[paidBy] ?? 0.0) + amount;
        for (var participant in participants) {
          balances[participant] = (balances[participant] ?? 0.0) - sharePerPerson;
        }
        // Note: paidBy is already included in participants loop above, so no need to deduct again
      } else if (split == 'unequally' && transaction['shares'] != null) {
        final shares = Map<String, dynamic>.from(transaction['shares']);
        balances[paidBy] = (balances[paidBy] ?? 0.0) + amount;
        for (var participant in participants) {
          final shareOriginal = shares[participant]?.toDouble() ?? 0.0;
          final shareConverted = currencyProvider.convertToSelectedCurrency(shareOriginal, fromCurrency);
          balances[participant] = (balances[participant] ?? 0.0) - shareConverted;
        }
        // Note: paidBy is already included in participants loop above, so no need to deduct again
      } else if (split == 'percentage' && transaction['shares'] != null) {
        final shares = Map<String, dynamic>.from(transaction['shares']);
        balances[paidBy] = (balances[paidBy] ?? 0.0) + amount;
        for (var participant in participants) {
          final percentage = shares[participant]?.toDouble() ?? 0.0;
          final shareOriginal = originalAmount * percentage / 100;
          final shareConverted = currencyProvider.convertToSelectedCurrency(shareOriginal, fromCurrency);
          balances[participant] = (balances[participant] ?? 0.0) - shareConverted;
        }
        // Note: paidBy is already included in participants loop above, so no need to deduct again
      }
    }
    // After all balances are calculated, round balances close to zero to zero
    balances.updateAll((key, value) => (value.abs() < 0.01) ? 0.0 : value);
    double consolidatedUserBalance = 0.0;
    for (String key in _getUserKeys(user)) {
      if (balances.containsKey(key)) {
        consolidatedUserBalance += balances[key] ?? 0.0;
        balances.remove(key);
      }
    }

    // Filter to show only people who owe you money (negative balances for others)
    final peopleWhoOweYou = balances.entries
        .where((entry) => !_getUserKeys(user).contains(entry.key) && entry.value < -0.01)
        .toList();
    // Filter to show people you owe money to (positive balances for others)
    final peopleYouOwe = balances.entries
        .where((entry) => !_getUserKeys(user).contains(entry.key) && entry.value > 0.01)
        .toList();
    final idToName = _buildIdToNameMap();
    final ownerIdDialog = widget.ownerId ?? FirebaseAuth.instance.currentUser?.uid;
    final filteredPeopleWhoOweYouDialog = peopleWhoOweYou.where((entry) => entry.key != ownerIdDialog && entry.value.abs() > 0.01).toList();
    final filteredPeopleYouOweDialog = peopleYouOwe.where((entry) => entry.key != ownerIdDialog && entry.value.abs() > 0.01).toList();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settle Up'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select who you want to settle up with:'),
              const SizedBox(height: 16),
              ...filteredPeopleWhoOweYouDialog.map((entry) {
                final rawKey = entry.key;
                final displayName = idToName[rawKey] ?? rawKey; // fallback to rawKey if not found
                final amount = entry.value.abs();
                return ListTile(
                  title: Text(displayName),
                  subtitle: Text('${displayName} owes you ${currencyProvider.formatAmount(amount)}'),
                  onTap: () {
                    Navigator.pop(context);
                    _showSettlementAmountDialog(SettlementOption(name: displayName, balance: entry.value, displayText: '${displayName} owes you ${currencyProvider.formatAmount(amount)}'));
                  },
                );
              }).toList(),
              ...filteredPeopleYouOweDialog.map((entry) {
                final rawKey = entry.key;
                final displayName = idToName[rawKey] ?? rawKey; // fallback to rawKey if not found
                final amount = entry.value;
                return ListTile(
                  title: Text(displayName),
                  subtitle: Text('You owe $displayName ${currencyProvider.formatAmount(amount)}'),
                  onTap: () {
                    Navigator.pop(context);
                    _showSettlementAmountDialog(SettlementOption(name: displayName, balance: entry.value, displayText: 'You owe $displayName ${currencyProvider.formatAmount(amount)}'));
                  },
                );
              }).toList(),
            ],
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

  // Get settlement options
  List<SettlementOption> _getSettlementOptions() {
    if (_activity == null || _activity!['balances'] == null) {
      return [];
    }
    
    final balances = Map<String, double>.from(_activity!['balances']);
    final options = <SettlementOption>[];
    
    // Add people who owe you money
    for (var entry in balances.entries) {
      if (entry.key != 'You' && entry.value < 0) {
        options.add(SettlementOption(
          name: entry.key,
          balance: entry.value,
          displayText: '${entry.key} owes you ${_activity!['currency'] ?? '\$'}${entry.value.abs().toStringAsFixed(2)}',
        ));
      }
    }
    
    // Add people you owe money to
    for (var entry in balances.entries) {
      if (entry.key != 'You' && entry.value > 0) {
        options.add(SettlementOption(
          name: entry.key,
          balance: entry.value,
          displayText: 'You owe ${entry.key} ${_activity!['currency'] ?? '\$'}${entry.value.toStringAsFixed(2)}',
        ));
      }
    }
    
    return options;
  }

  // Add method to create settlement transaction
  Future<void> _createSettlementTransaction(String person, double balance) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);

        // Get the activity's original currency
        final activityCurrency = _activity!['currency'] ?? 'USD';
        final activityCurrencyObj = currencyProvider.getCurrencyByCode(activityCurrency) ??
                                   currencyProvider.selectedCurrency;

        // Convert the settlement amount to the activity's currency if needed
        final settlementAmountInActivityCurrency = currencyProvider.convertCurrency(
          balance.abs(),
          currencyProvider.selectedCurrency,
          activityCurrencyObj
        );

        // Determine who is paying whom
        final isPositive = balance >= 0;
        final settlementTitle = isPositive
            ? 'You settled debt with $person'
            : '$person settled debt with you';

        // Use the actual user ID instead of "You" for consistency with balance calculations
        final currentUserKey = user.uid;

        // Create a settlement transaction
        final settlement = {
          'title': settlementTitle,
          'amount': settlementAmountInActivityCurrency,
          'currency': activityCurrency,
          'date': DateFormat.yMMMd().format(DateTime.now()),
          'description': 'Settlement transaction',
          'paid_by': isPositive ? currentUserKey : person,
          'split': 'settlement', // Use a special split type for settlements
          'participants': [person], // Only the other person participates in settlement
          'settlement_amount': settlementAmountInActivityCurrency,
          'settlement_from': isPositive ? currentUserKey : person,
          'settlement_to': isPositive ? person : currentUserKey,
          'is_settlement': true,
          'timestamp': FieldValue.serverTimestamp(),
        };
        
        // Add the settlement transaction to the activity
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('activities')
            .doc(widget.activityId)
            .collection('transactions')
            .add(settlement);
        
        // Reload activity data to update balances
        await _recalculateActivityTotals();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settlement recorded successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording settlement: $e')),
        );
      }
    }
  }

  // Add this method to generate and export a PDF report
  Future<void> _generateActivityReport() async {
    try {
      if (_activity == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No activity data to export')),
        );
        return;
      }

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating report...')),
      );

      // Create a PDF document
      final pdf = pw.Document();
      
      // Add activity info page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Text(
                    'Activity Report',
                    style: pw.TextStyle(
                      fontSize: 24, 
                      fontWeight: pw.FontWeight.bold
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // Activity details
                pw.Text(
                  'Activity: ${_activity!['name']}',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Date: ${DateFormat('MMMM d, yyyy').format((_activity!['createdAt'] as Timestamp).toDate())}',
                ),
                if (_activity!['description'] != null && _activity!['description'] != '') ...[
                  pw.SizedBox(height: 5),
                  pw.Text('Description: ${_activity!['description']}'),
                ],
                pw.SizedBox(height: 10),
                pw.Text(
                  'Total Amount: ${_activity!['currency'] ?? '\$'}${(_activity!['totalAmount'] ?? 0.0).toStringAsFixed(2)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Divider(),
                
                // Balances section
                pw.Text(
                  'Balances',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
              ],
            );
          },
        ),
      );
      
      // Add balances page
      if (_activity!['balances'] != null) {
        final balances = Map<String, double>.from(_activity!['balances']);
        final currentUserBalance = balances['You'] ?? 0.0;
        
        // People who owe you
        final peopleWhoOweYou = balances.entries
            .where((entry) => entry.key != 'You' && entry.value < 0)
            .toList();
        
        // People you owe
        final peopleYouOwe = balances.entries
            .where((entry) => entry.key != 'You' && entry.value > 0)
            .toList();
        
        final idToName = _buildIdToNameMap();
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Balances',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 20),
                  
                  // Your balance
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Your balance:'),
                      pw.Text(
                        '${currentUserBalance >= 0 ? '+' : ''}${currentUserBalance.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  
                  // People who owe you
                  if (peopleWhoOweYou.isNotEmpty) ...[
                    pw.Text('People who owe you:'),
                    pw.SizedBox(height: 10),
                    ...peopleWhoOweYou.map((entry) {
                      final rawKey = entry.key;
                      final displayName = idToName[rawKey] ?? rawKey;
                      final amount = entry.value.abs();
                      
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(displayName),
                            pw.Text(
                              '${_activity!['currency'] ?? '\$'}${amount.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    pw.SizedBox(height: 20),
                  ],
                  
                  // People you owe
                  if (peopleYouOwe.isNotEmpty) ...[
                    pw.Text('You owe:'),
                    pw.SizedBox(height: 10),
                    ...peopleYouOwe.map((entry) {
                      final rawKey = entry.key;
                      final displayName = idToName[rawKey] ?? rawKey;
                      final amount = entry.value;
                      
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(displayName),
                            pw.Text(
                              '${_activity!['currency'] ?? '\$'}${amount.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              );
            },
          ),
        );
      }
      
      // Add transactions page
      if (_transactions.isNotEmpty) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'Transactions',
                      style: pw.TextStyle(
                        fontSize: 20, 
                        fontWeight: pw.FontWeight.bold
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  
                  // Transactions table
                  pw.Table(
                    border: pw.TableBorder.all(),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3), // Title
                      1: const pw.FlexColumnWidth(2), // Paid by
                      2: const pw.FlexColumnWidth(2), // Amount
                      3: const pw.FlexColumnWidth(2), // Date
                    },
                    children: [
                      // Table header
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey300,
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              'Title',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              'Paid by',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              'Amount',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              'Date',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      
                      // Transaction rows (limit to first 20 to avoid overflow)
                      ...(_transactions.length > 20 ? _transactions.sublist(0, 20) : _transactions).map((transaction) {
                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(transaction['title'] ?? 'Untitled'),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(transaction['paid_by'] ?? ''),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(
                                '${_activity!['currency'] ?? '\$'}${(transaction['amount']?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(transaction['date'] ?? ''),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      }
      
      // Generate PDF bytes
      final pdfBytes = await pdf.save();
      
      // Share the PDF directly without saving to a file
      await Share.shareXFiles(
        [
          XFile.fromData(
            pdfBytes,
            name: '${_activity!['name'].toString().replaceAll(' ', '_')}_report.pdf',
            mimeType: 'application/pdf',
          ),
        ],
        text: 'Activity Report',
      );
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report generated and ready to share')),
      );
      
    } catch (e) {
      print('Error generating PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    }
  }

  // Show dialog with export options
  void _showExportOptionsDialog(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Generated'),
        content: const Text('Your activity report has been generated. What would you like to do with it?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('View'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Share.shareFiles([file.path], text: 'Activity Report');
            },
            child: const Text('Share'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Show dialog to enter settlement amount
  void _showSettlementAmountDialog(SettlementOption option) {
    final TextEditingController amountController = TextEditingController(
      text: option.balance.abs().toStringAsFixed(2)
    );
    final isPositive = option.balance >= 0;
    final maxAmount = option.balance.abs();
    
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final selectedCurrency = currencyProvider.selectedCurrency;
    final currencySymbol = selectedCurrency.symbol;
    
    final activityCurrency = _activity!['currency'] ?? 'USD';
    final activityCurrencyObj = currencyProvider.getCurrencyByCode(activityCurrency) ?? selectedCurrency;
    final amountInActivityCurrency = currencyProvider.convertCurrency(
      option.balance.abs(),
      selectedCurrency,
      activityCurrencyObj,
    );
    final activityCurrencySymbol = activityCurrencyObj.symbol;
    
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
                  ? 'You owe ${option.name} $currencySymbol${maxAmount.toStringAsFixed(2)}'
                  : '${option.name} owes you $currencySymbol${maxAmount.toStringAsFixed(2)}'
            ),
            const SizedBox(height: 16),
            const Text('How much would you like to settle?'),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: currencySymbol,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter an amount between 0 and ${maxAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                  SnackBar(content: Text('Amount cannot exceed ${maxAmount.toStringAsFixed(2)}')),
                );
                return;
              }
              Navigator.pop(context);
              _createSettlementTransaction(option.name, isPositive ? amount : -amount);
            },
            child: const Text('Settle'),
          ),
        ],
      ),
    );
  }

  // Add this method to recalculate totals and balances whenever transactions change
  Future<void> _recalculateActivityTotals({bool skipDataReload = false}) async {
    if (_transactions.isEmpty) {
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);

      // Use USD as the universal base currency for database storage
      // This ensures consistency regardless of when transactions were created
      final baseCurrencyObj = currencyProvider.availableCurrencies.firstWhere(
        (c) => c.code == 'USD',
        orElse: () => currencyProvider.selectedCurrency,
      );

      // Calculate total amount spent in USD BASE CURRENCY (excluding settlements)
      double totalAmount = 0.0;
      for (var transaction in _transactions) {
        // Skip settlement transactions when calculating total spent
        if (transaction['is_settlement'] == true) {
          continue;
        }

        final originalAmount = transaction['amount']?.toDouble() ?? 0.0;
        final originalCurrency = transaction['currency'] ?? 'USD';
        final fromCurrency = currencyProvider.availableCurrencies.firstWhere(
          (c) => c.code == originalCurrency,
          orElse: () => baseCurrencyObj,
        );
        // Convert to USD base currency for consistent database storage
        final convertedAmount = currencyProvider.convertCurrency(originalAmount, fromCurrency, baseCurrencyObj);
        totalAmount += convertedAmount;
      }

      // Calculate balances in USD BASE CURRENCY
      Map<String, double> balances = {};
      if (_activity != null && _activity!['members'] != null) {
        for (var member in _activity!['members']) {
          final id = member is Map ? (member['id'] ?? member['email'] ?? member['name']) : member;
          balances[id] = 0.0;
        }
      }

      for (var transaction in _transactions) {
        final paidBy = transaction['paid_by'] ?? '';
        final originalAmount = transaction['amount']?.toDouble() ?? 0.0;
        final originalCurrency = transaction['currency'] ?? 'USD';
        final fromCurrency = currencyProvider.availableCurrencies.firstWhere(
          (c) => c.code == originalCurrency,
          orElse: () => baseCurrencyObj,
        );
        // Convert to USD base currency for consistent database storage
        final amount = currencyProvider.convertCurrency(originalAmount, fromCurrency, baseCurrencyObj);
        final split = transaction['split'] ?? 'equally';
        final participants = List<String>.from(transaction['participants'] ?? []);

        // Handle settlement transactions
        if (transaction['is_settlement'] == true) {
          final settlementFrom = transaction['settlement_from'] ?? '';
          final settlementTo = transaction['settlement_to'] ?? '';
          final settlementAmount = amount;

          // Apply settlement: reduce debt between parties
          // When someone pays to settle debt, their balance increases (less negative or more positive)
          // and the receiver's balance decreases (less positive or more negative)
          if (settlementFrom.isNotEmpty && settlementTo.isNotEmpty) {
            // Handle both old format ("You") and new format (user ID)
            String actualSettlementFrom = settlementFrom;
            String actualSettlementTo = settlementTo;

            // Convert "You" to actual user ID for consistency
            if (settlementFrom == 'You') {
              actualSettlementFrom = user.uid;
            }
            if (settlementTo == 'You') {
              actualSettlementTo = user.uid;
            }

            balances[actualSettlementFrom] = (balances[actualSettlementFrom] ?? 0.0) + settlementAmount;
            balances[actualSettlementTo] = (balances[actualSettlementTo] ?? 0.0) - settlementAmount;
          }
          continue;
        }
        if (split == 'equally' && participants.isNotEmpty) {
          final sharePerPerson = amount / participants.length;
          balances[paidBy] = (balances[paidBy] ?? 0.0) + amount;
          for (var participant in participants) {
            balances[participant] = (balances[participant] ?? 0.0) - sharePerPerson;
          }
          // Note: paidBy is already included in participants loop above, so no need to deduct again
        } else if (split == 'unequally' && transaction['shares'] != null) {
          final shares = Map<String, dynamic>.from(transaction['shares']);
          balances[paidBy] = (balances[paidBy] ?? 0.0) + amount;
          for (var participant in participants) {
            final shareOriginal = shares[participant]?.toDouble() ?? 0.0;
            final shareConverted = currencyProvider.convertCurrency(shareOriginal, fromCurrency, baseCurrencyObj);
            balances[participant] = (balances[participant] ?? 0.0) - shareConverted;
          }
          // Note: paidBy is already included in participants loop above, so no need to deduct again
        } else if (split == 'percentage' && transaction['shares'] != null) {
          final shares = Map<String, dynamic>.from(transaction['shares']);
          balances[paidBy] = (balances[paidBy] ?? 0.0) + amount;
          for (var participant in participants) {
            final percentage = shares[participant]?.toDouble() ?? 0.0;
            final shareOriginal = originalAmount * percentage / 100;
            final shareConverted = currencyProvider.convertCurrency(shareOriginal, fromCurrency, baseCurrencyObj);
            balances[participant] = (balances[participant] ?? 0.0) - shareConverted;
          }
          // Note: paidBy is already included in participants loop above, so no need to deduct again
        }
      }

      // After all balances are calculated, round balances close to zero to zero
      balances.updateAll((key, value) => (value.abs() < 0.01) ? 0.0 : value);
      double consolidatedUserBalance = 0.0;
      for (String key in _getUserKeys(user)) {
        if (balances.containsKey(key)) {
          consolidatedUserBalance += balances[key] ?? 0.0;
          balances.remove(key);
        }
      }

      DocumentReference activityRef;
      if (_isCreator) {
        activityRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('activities')
            .doc(widget.activityId);
      } else {
        activityRef = _firestore
            .collection('users')
            .doc(widget.ownerId)
            .collection('activities')
            .doc(widget.activityId);
      }

      await activityRef.update({
        'totalAmount': totalAmount,
        'balances': balances,
      });

      if (!skipDataReload) {
        await _loadActivityData();
      }
    } catch (e) {
      print('Error recalculating totals: $e');
    }
  }

  Future<void> _deleteTransactionAndRefresh(String transactionId) async {
    final user = _auth.currentUser;
    if (user != null) {
      DocumentReference activityRef = _isCreator
          ? _firestore.collection('users').doc(user.uid).collection('activities').doc(widget.activityId)
          : _firestore.collection('users').doc(widget.ownerId).collection('activities').doc(widget.activityId);
      await activityRef.collection('transactions').doc(transactionId).delete();
      await _recalculateActivityTotals();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
      title: Text(
        widget.title,
        style: TextStyle(color: Colors.white), 
      ),
      iconTheme: IconThemeData(color: Colors.white), 
      backgroundColor: const Color(0xFFF5A9C1), 
      elevation: 4,
      actions: [
        IconButton(
          icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
          onPressed: () async {
            final user = FirebaseAuth.instance.currentUser; 

            if (user == null) return; 

            final updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TotalSpent(
                  activityId: widget.activityId,
                  ownerUid: _isCreator ? user.uid : widget.ownerId!,
                  activityData: _activity!,
                ),
              ),
            );

            if (updated == true) {
              _loadActivityData();
            }
          },
        ),
        if (_isCreator)
          IconButton(
            icon: Icon(Icons.edit, color: Colors.white), 
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditActivityScreen(activityData: _activity!),
                ),
              );

              if (updated == true) {
                _loadActivityData();
              }
            },
          ),
      ],
    ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activity == null
              ? const Center(child: Text('Activity not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      //_buildActivitySummary(),
                      // Activity Header
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(
                                        0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.hiking,
                                      color: AppTheme.primaryColor,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _activity!['name'],
                                                style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.file_download),
                                              onPressed: _generateActivityReport,
                                            ),
                                          ],
                                        ),
                                        Text(
                                          DateFormat('MMMM d, yyyy').format(
                                            (_activity!['createdAt']
                                                    as Timestamp)
                                                .toDate(),
                                          ),
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              if (_activity!['description'] != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  _activity!['description'],
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              _buildBalancesCard(),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Transactions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Transactions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AddExpenseScreen(
                                    activityId: _activity!['id'],
                                    activityName: _activity!['name'],
                                    ownerId: widget.ownerId,
                                  ),
                                ),
                              ).then((_) => _loadActivityData());
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _transactions.isEmpty
                          ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text(
                                'No transactions yet',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ),
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              return _buildTransactionItem(
                                _transactions[index],
                              );
                            },
                          ),
                      Padding(padding: const EdgeInsets.only(bottom: 70.0)),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddExpenseScreen(
                activityId: _activity!['id'],
                activityName: _activity!['name'],
                ownerId: widget.ownerId,
              ),
            ),
          ).then((_) => _loadActivityData());
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
}

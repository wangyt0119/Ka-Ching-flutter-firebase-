import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'add_expense_screen.dart';
import '../../services/currency_service.dart';
import '../settings/currency_screen.dart';
import 'transaction_detail_screen.dart';
import '../activities/activity_detail_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _allTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to currency changes and reload transactions
    Provider.of<CurrencyProvider>(context).addListener(_onCurrencyChanged);
  }

  @override
  void dispose() {
    Provider.of<CurrencyProvider>(context, listen: false).removeListener(_onCurrencyChanged);
    super.dispose();
          }

  void _onCurrencyChanged() {
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Get all users (to find activities where user is a participant)
        final usersSnapshot = await _firestore.collection('users').get();
        List<Map<String, dynamic>> transactions = [];

        for (var userDoc in usersSnapshot.docs) {
          final ownerId = userDoc.id;
        final activitiesSnapshot = await _firestore
            .collection('users')
              .doc(ownerId)
            .collection('activities')
            .get();
        
        for (var activityDoc in activitiesSnapshot.docs) {
          final activityData = activityDoc.data();
            final activityId = activityDoc.id;
            final activityName = activityData['name'] ?? 'Unnamed Activity';
            final members = activityData['members'] as List<dynamic>? ?? [];
          
            // Check if current user is a participant or owner
            bool isParticipant = false;
            for (var member in members) {
              if (member is Map<String, dynamic> &&
                  (member['id'] == user.uid || member['email'] == user.email || member['name'] == 'You')) {
                isParticipant = true;
                break;
              }
            }
            if (ownerId == user.uid) isParticipant = true;
            if (!isParticipant) continue;

            // Get transactions for this activity
            final transactionsSnapshot = await _firestore
                .collection('users')
                .doc(ownerId)
                .collection('activities')
                .doc(activityId)
                .collection('transactions')
                .orderBy('timestamp', descending: true)
                .get();

            for (var transactionDoc in transactionsSnapshot.docs) {
              final transactionData = transactionDoc.data();
              transactionData['id'] = transactionDoc.id;
              transactionData['activityId'] = activityId;
              transactionData['activityName'] = activityName;
              transactionData['ownerId'] = ownerId;

              // Only show if user is a participant or payer
              final participants = List<String>.from(transactionData['participants'] ?? []);
              final paidBy = transactionData['paid_by'];
              if (participants.contains('You') || paidBy == 'You' || ownerId == user.uid) {
                // Calculate user's share in this transaction
                double userShare = 0.0;
                if (paidBy == 'You') {
                  final totalAmount = transactionData['amount']?.toDouble() ?? 0.0;
                  if (participants.contains('You')) {
                    if (transactionData['split'] == 'equally') {
                      userShare = totalAmount / participants.length;
                    } else if (transactionData['split'] == 'unequally' && transactionData['shares'] != null) {
                      final shares = Map<String, dynamic>.from(transactionData['shares']);
                      userShare = shares['You']?.toDouble() ?? 0.0;
                    } else if (transactionData['split'] == 'percentage' && transactionData['shares'] != null) {
                      final shares = Map<String, dynamic>.from(transactionData['shares']);
                      final percentage = shares['You']?.toDouble() ?? 0.0;
                      userShare = totalAmount * percentage / 100;
                    }
                  }
                } else {
                  final totalAmount = transactionData['amount']?.toDouble() ?? 0.0;
                  if (participants.contains('You')) {
                    if (transactionData['split'] == 'equally') {
                      userShare = -totalAmount / participants.length;
                    } else if (transactionData['split'] == 'unequally' && transactionData['shares'] != null) {
                      final shares = Map<String, dynamic>.from(transactionData['shares']);
                      userShare = -(shares['You']?.toDouble() ?? 0.0);
                    } else if (transactionData['split'] == 'percentage' && transactionData['shares'] != null) {
                      final shares = Map<String, dynamic>.from(transactionData['shares']);
                      final percentage = shares['You']?.toDouble() ?? 0.0;
                      userShare = -(totalAmount * percentage / 100);
                    }
                  }
                }
                transactionData['userShare'] = userShare;
                transactions.add(transactionData);
              }
            }
          }
        }

        setState(() {
          _allTransactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading transactions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filterTransactions(List<Map<String, dynamic>> transactions) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    final userEmail = user?.email;
    // Update userShare calculation to use userId/email
    for (var t in transactions) {
      final participants = List<String>.from(t['participants'] ?? []);
      String userKey = '';
      if (participants.contains(userId)) {
        userKey = userId!;
      } else if (participants.contains(userEmail)) {
        userKey = userEmail!;
      }
      double userShare = 0.0;
      if (userKey.isNotEmpty) {
        if (t['split'] == 'equally') {
          userShare = (t['amount'] ?? 0.0) / participants.length;
        } else if (t['split'] == 'unequally' && t['shares'] != null) {
          final shares = Map<String, dynamic>.from(t['shares']);
          userShare = shares[userKey]?.toDouble() ?? 0.0;
        } else if (t['split'] == 'percentage' && t['shares'] != null) {
          final shares = Map<String, dynamic>.from(t['shares']);
          final percentage = shares[userKey]?.toDouble() ?? 0.0;
          userShare = (t['amount'] ?? 0.0) * percentage / 100;
        }
      }
      final paidBy = t['paid_by'];
      final isPayer = paidBy == userKey;
      t['userShare'] = isPayer ? userShare : -userShare;
    }
    if (_selectedFilter == 'All') {
      return transactions;
    } else if (_selectedFilter == 'Owe') {
      return transactions.where((t) => (t['userShare'] as double) < 0).toList();
    } else if (_selectedFilter == 'Owed') {
      return transactions.where((t) => (t['userShare'] as double) > 0).toList();
    }
    return transactions;
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final selectedCurrency = currencyProvider.selectedCurrency;
    final filteredTransactions = _filterTransactions(_allTransactions);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5A9C1),
        elevation: 0,
        title: const Text(
          'Transactions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (String value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'All',
                    child: Text('All Transactions'),
                  ),
                  const PopupMenuItem(value: 'Owe', child: Text('I Owe')),
                  const PopupMenuItem(value: 'Owed', child: Text('I\'m Owed')),
                ],
          ),
          IconButton(
            icon: const Icon(Icons.currency_exchange, color: Colors.white),
            onPressed: () async {
              await _showCurrencyDialog();
              _loadTransactions(); // Reload transactions with new currency
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredTransactions.isEmpty
              ? Center(
                    child: Text(
                      'No ${_selectedFilter.toLowerCase()} transactions found',
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                )
              : ListView.builder(
                  itemCount: filteredTransactions.length,
                  itemBuilder: (context, index) {
                    final transaction = filteredTransactions[index];
                    final originalAmount = transaction['amount']?.toDouble() ?? 0.0;
                    final originalCurrency = transaction['currency'] ?? 'USD';
                    final fromCurrency = currencyProvider.availableCurrencies.firstWhere(
                      (c) => c.code == originalCurrency,
                      orElse: () => currencyProvider.selectedCurrency,
                    );
                    final convertedAmount = currencyProvider.convertToSelectedCurrency(originalAmount, fromCurrency);
                    final userShare = transaction['userShare'] as double;
                    final convertedUserShare = currencyProvider.convertToSelectedCurrency(userShare.abs(), fromCurrency);
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TransactionDetailScreen(
                                transactionId: transaction['id'],
                                activityId: transaction['activityId'],
                              ),
                            ),
                          ).then((_) => _loadTransactions());
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                          transaction['title'] ?? 'Untitled',
                                      style: const TextStyle(
                                            fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          transaction['activityName'] ?? 'Unknown Activity',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                        ),
                                      ],
                                      ),
                                    ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // Original value
                                      Text(
                                        '$originalCurrency ${originalAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      // Converted value
                                      Text(
                                        currencyProvider.formatAmount(convertedAmount),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: userShare > 0
                                              ? const Color.fromARGB(255, 214, 244, 215)
                                              : const Color.fromARGB(255, 254, 213, 217),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          userShare > 0
                                              ? 'You get back ${currencyProvider.formatAmount(convertedUserShare)}'
                                              : 'You owe ${currencyProvider.formatAmount(convertedUserShare)}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: userShare > 0 ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    transaction['date'] ?? 'Unknown date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Paid by ${transaction['paid_by'] ?? 'Unknown'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
      ),
    );
  }

  Future<void> _showCurrencyDialog() async {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final currencies = currencyProvider.availableCurrencies;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: currencies.length,
            itemBuilder: (context, index) {
              final currency = currencies[index];
                return ListTile(
                title: Text('${currency.name} (${currency.code})'),
                trailing: currency.code == currencyProvider.selectedCurrency.code
                    ? const Icon(Icons.check, color: Color(0xFFF5A9C1))
                    : null,
                onTap: () async {
                  await currencyProvider.setSelectedCurrency(currency);
                  if (mounted) {
                    Navigator.pop(context);
                  }
                  },
                );
            },
          ),
        ),
      ),
    );
  }
}

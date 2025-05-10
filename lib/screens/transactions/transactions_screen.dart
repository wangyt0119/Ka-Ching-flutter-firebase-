import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/currency_service.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'All';
  String _selectedCurrency = 'USD';

  @override
  void initState() {
    super.initState();
    _loadUserCurrency();
  }

  Future<void> _loadUserCurrency() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        final DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();

        if (userDoc.exists) {
          setState(() {
            _selectedCurrency = userDoc.get('currency') ?? 'USD';
          });
        }
      }
    } catch (e) {
      print('Error loading currency: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFF5A9C1),
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
            itemBuilder:
                (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'All',
                    child: Text('All Transactions'),
                  ),
                  const PopupMenuItem(value: 'Income', child: Text('Income')),
                  const PopupMenuItem(value: 'Expense', child: Text('Expense')),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chip
          Container(
            padding: const EdgeInsets.all(16),
            color: Color(0xFFF5A9C1),
            child: Row(
              children: [
                Text(
                  'Filter: $_selectedFilter',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  'Currency: $_selectedCurrency',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  _firestore
                      .collection('transactions')
                      .where('user_id', isEqualTo: _auth.currentUser?.uid)
                      .orderBy('date', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final transactions = snapshot.data?.docs ?? [];
                final filteredTransactions =
                    transactions.where((doc) {
                      if (_selectedFilter == 'All') return true;
                      return doc['type'] == _selectedFilter;
                    }).toList();

                if (filteredTransactions.isEmpty) {
                  return const Center(
                    child: Text(
                      'No transactions yet. Add some to get started!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredTransactions.length,
                  itemBuilder: (context, index) {
                    final transaction = filteredTransactions[index];
                    final amount = transaction['amount'] as double;
                    final isExpense = transaction['type'] == 'Expense';
                    final date = (transaction['date'] as Timestamp).toDate();
                    final transactionCurrency =
                        transaction['currency'] ?? 'USD';

                    return FutureBuilder<double>(
                      future: CurrencyService.convertCurrency(
                        amount,
                        transactionCurrency,
                        _selectedCurrency,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final convertedAmount = snapshot.data ?? amount;
                        final formattedAmount = CurrencyService.formatCurrency(
                          convertedAmount,
                          _selectedCurrency,
                        );

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  isExpense
                                      ? Colors.red.withOpacity(0.2)
                                      : Colors.green.withOpacity(0.2),
                              child: Icon(
                                isExpense ? Icons.remove : Icons.add,
                                color: isExpense ? Colors.red : Colors.green,
                              ),
                            ),
                            title: Text(
                              transaction['description'] ?? 'No description',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              DateFormat('MMM dd, yyyy').format(date),
                              style: const TextStyle(color: Colors.grey),
                            ),
                            trailing: Text(
                              '${isExpense ? '-' : '+'}$formattedAmount',
                              style: TextStyle(
                                color: isExpense ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFFF5A9C1),
        onPressed: () {
          // TODO: Implement add transaction functionality
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Add Transaction'),
                  content: const Text(
                    'Transaction form will be implemented here',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

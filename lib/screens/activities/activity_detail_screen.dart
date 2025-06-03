import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../transactions/add_expense_screen.dart';
import 'edit_activity_screen.dart';
import '../transactions/transaction_detail_screen.dart';

// Helper class for settlement options - move to top level outside the class
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

  const ActivityDetailsScreen({super.key, required this.activityId});

  @override
  State<ActivityDetailsScreen> createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _activity;
  List<Map<String, dynamic>> _transactions = [];

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
        // Load activity details
        final activityDoc =
            await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('activities')
                .doc(widget.activityId)
                .get();

        if (activityDoc.exists) {
          final activityData = activityDoc.data()!;
          activityData['id'] = activityDoc.id;

          // Load transactions for this activity
          final transactionsSnapshot =
              await _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('activities')
                  .doc(widget.activityId)
                  .collection('transactions')
                  .orderBy('date', descending: true)
                  .get();

          final transactions =
              transactionsSnapshot.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              }).toList();

          // Calculate total amount and balances
          double totalAmount = 0;
          Map<String, double> balances = {};

          for (var transaction in transactions) {
            final amount = transaction['amount']?.toDouble() ?? 0.0;
            final paidBy = transaction['paid_by'] ?? 'Unknown';
            final participants = List<String>.from(transaction['participants'] ?? []);
            
            print('Processing transaction: ${transaction['title']} with amount: $amount');
            print('Paid by: $paidBy, Participants: $participants');
            
            totalAmount += amount;

            // Add to payer's balance (they paid)
            balances[paidBy] = (balances[paidBy] ?? 0) + amount;

            // Subtract from participants' balances (they owe)
            final splitMethod = transaction['split'] ?? 'equally';
            
            if (splitMethod == 'equally' && participants.isNotEmpty) {
              final shareAmount = amount / participants.length;
              
              for (var participant in participants) {
                if (participant != paidBy) {
                  balances[participant] = (balances[participant] ?? 0) - shareAmount;
                }
              }
            } else if (splitMethod == 'percentage' && transaction['shares'] != null) {
              final shares = Map<String, dynamic>.from(transaction['shares']);
              
              for (var entry in shares.entries) {
                final participant = entry.key;
                final percentage = entry.value;
                
                if (participant != paidBy) {
                  final shareAmount = amount * percentage / 100;
                  balances[participant] = (balances[participant] ?? 0) - shareAmount;
                }
              }
            }
          }

          // After updating balances, log them
          print('Updated balances: $balances');

          // Update activity with total amount
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('activities')
              .doc(widget.activityId)
              .update({
            'totalAmount': totalAmount,
            'balances': balances,
          });

          activityData['totalAmount'] = totalAmount;
          activityData['balances'] = balances;

          setState(() {
            _activity = activityData;
            _transactions = transactions;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading activity: ${e.toString()}')),
      );
    }
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final isCurrentUserPayer = transaction['paid_by'] == 'You';
    final amount = transaction['amount']?.toDouble() ?? 0.0;
    final date = transaction['date'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionDetailScreen(
                transactionId: transaction['id'],
                activityId: widget.activityId,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt,
                      color: AppTheme.primaryColor,
                      size: 20,
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
                          'Paid by ${isCurrentUserPayer ? 'you' : transaction['paid_by']}',
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
                      Text(
                        '\$${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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
            ],
          ),
        ),
      ),
    );
  }

  // Add a method to show who owes you money
  Widget _buildBalancesCard() {
    if (_activity == null || _activity!['balances'] == null) {
      return const SizedBox();
    }

    final balances = Map<String, double>.from(_activity!['balances']);
    final currentUserBalance = balances['You'] ?? 0.0;
    
    // Filter to show only people who owe you money (negative balances for others)
    final peopleWhoOweYou = balances.entries
        .where((entry) => entry.key != 'You' && entry.value < 0)
        .toList();
    
    // Filter to show people you owe money to (positive balances for others)
    final peopleYouOwe = balances.entries
        .where((entry) => entry.key != 'You' && entry.value > 0)
        .toList();

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
                  '${currentUserBalance >= 0 ? '+' : ''}${currentUserBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: currentUserBalance >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // People who owe you money
            if (peopleWhoOweYou.isNotEmpty) ...[
              const Text(
                'People who owe you:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...peopleWhoOweYou.map((entry) {
                final name = entry.key;
                final amount = entry.value.abs(); // Make positive for display
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name),
                      Text(
                        '${_activity!['currency'] ?? '\$'}${amount.toStringAsFixed(2)}',
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
            if (peopleYouOwe.isNotEmpty) ...[
              const Text(
                'You owe:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...peopleYouOwe.map((entry) {
                final name = entry.key;
                final amount = entry.value; // Already positive
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name),
                      Text(
                        '${_activity!['currency'] ?? '\$'}${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
            
            // Add settle up button
            if (peopleWhoOweYou.isNotEmpty || peopleYouOwe.isNotEmpty) ...[
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
              ..._getSettlementOptions().map((option) {
                return ListTile(
                  title: Text(option.name),
                  subtitle: Text(option.displayText),
                  onTap: () {
                    Navigator.pop(context);
                    _createSettlementTransaction(option.name, option.balance);
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
        // Determine who is paying whom
        final isPositive = balance >= 0;
        final settlementTitle = isPositive 
            ? 'You settled debt with $person' 
            : '$person settled debt with you';
        
        // Create a settlement transaction
        final settlement = {
          'title': settlementTitle,
          'amount': balance.abs(),
          'currency': _activity!['currency'] ?? '\$',
          'date': DateFormat.yMMMd().format(DateTime.now()),
          'description': 'Settlement transaction',
          'paid_by': isPositive ? 'You' : person,
          'split': 'equally',
          'participants': [isPositive ? person : 'You'],
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
        await _loadActivityData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settlement recorded successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording settlement: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_activity?['name'] ?? 'Activity Details'),
        backgroundColor: const Color(0xFFF5A9C1),
        actions: [
          IconButton(
  icon: Icon(Icons.edit),
  onPressed: () async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditActivityScreen(activityData: _activity!),
      ),
    );

    // Check if update happened, then reload
    if (updated == true) {
      _loadActivityData();
    }
  },
),


        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _activity == null
              ? const Center(child: Text('Activity not found'))
              : RefreshIndicator(
                onRefresh: _loadActivityData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                              icon: const Icon(
                                                Icons.file_download,
                                              ),
                                              onPressed: () {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Export functionality would be implemented here',
                                                    ),
                                                  ),
                                                );
                                              },
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
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total spent',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '\$${(_activity!['totalAmount'] ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
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
                                  builder:
                                      (_) => AddExpenseScreen(
                                        activityId: _activity!['id'],
                                        activityName: _activity!['name'],
                                      ),
                                ),
                              );
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
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => AddExpenseScreen(
                    activityId: _activity!['id'],
                    activityName: _activity!['name'],
                  ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
}

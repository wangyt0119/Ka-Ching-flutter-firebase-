import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'add_expense_screen.dart';
import '../../services/currency_service.dart';
import '../settings/currency_screen.dart';
import 'transaction_detail_screen.dart';
import '../activities/activity_detail_screen.dart';

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
  Map<String, double> _balances = {}; // Track balances across activities

  @override
  void initState() {
    super.initState();
    _loadUserCurrency();
    _calculateBalances();
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

  Future<void> _calculateBalances() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Debug: Add logging to check if activities are being fetched
        print('Fetching activities for balance calculation');
        
        final activitiesSnapshot = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('activities')
            .get();
        
        // Debug: Check if activities are found
        print('Found ${activitiesSnapshot.docs.length} activities');
        
        Map<String, double> balances = {};
        
        // For each activity, check if balances are properly calculated
        for (var activityDoc in activitiesSnapshot.docs) {
          final activityData = activityDoc.data();
          print('Processing activity: ${activityData['title']} with ID: ${activityDoc.id}');
          
          // Check if the activity has balances field
          if (activityData['balances'] != null) {
            print('Activity balances: ${activityData['balances']}');
          } else {
            print('No balances found in activity');
          }
          
          // Rest of your existing code...
        }
        
        // After calculation, log the final balances
        print('Final calculated balances: $balances');
        print('Total owed: ${balances['__total_owed'] ?? 0.0}');
        print('Total owing: ${balances['__total_owing'] ?? 0.0}');
        
        setState(() {
          _balances = balances;
        });
      }
    } catch (e) {
      print('Error calculating balances: $e');
    }
  }

  void _changeCurrency(String currency) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'currency': currency,
        });

        setState(() {
          _selectedCurrency = currency;
        });

        // Recalculate balances with new currency
        await _calculateBalances();
      }
    } catch (e) {
      print('Error updating currency: $e');
    }
  }

  void _showCurrencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: CurrencyService.supportedCurrencies.length,
            itemBuilder: (context, index) {
              final currency =
                  CurrencyService.supportedCurrencies.keys.elementAt(index);
              final currencyInfo =
                  CurrencyService.supportedCurrencies[currency];
              return ListTile(
                title: Text(currencyInfo ?? currency),
                trailing: currency == _selectedCurrency
                    ? const Icon(Icons.check, color: Color(0xFFF5A9C1))
                    : null,
                onTap: () {
                  _changeCurrency(currency);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterActivities(List<Map<String, dynamic>> activities) {
    if (_selectedFilter == 'All') {
      return activities;
    } else if (_selectedFilter == 'Owe') {
      // Show activities where you owe money
      return activities.where((activity) {
        final balance = activity['balance'] ?? 0.0;
        return balance < 0;
      }).toList();
    } else if (_selectedFilter == 'Owed') {
      // Show activities where you are owed money
      return activities.where((activity) {
        final balance = activity['balance'] ?? 0.0;
        return balance > 0;
      }).toList();
    }
    return activities;
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
                  const PopupMenuItem(value: 'Owe', child: Text('I Owe')),
                  const PopupMenuItem(value: 'Owed', child: Text('I\'m Owed')),
                ],
          ),
          IconButton(
            icon: const Icon(Icons.currency_exchange, color: Colors.white),
            onPressed: _showCurrencyDialog,
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

          // Balance Summary
          if (_balances.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Balance Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'You owe',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyService.formatCurrency(
                                    _balances['__total_owing'] ?? 0.0, 
                                    _selectedCurrency
                                  ),
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'You are owed',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyService.formatCurrency(
                                    _balances['__total_owed'] ?? 0.0, 
                                    _selectedCurrency
                                  ),
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Total balance',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyService.formatCurrency(
                          (_balances['__total_owed'] ?? 0.0) - (_balances['__total_owing'] ?? 0.0), 
                          _selectedCurrency
                        ),
                        style: TextStyle(
                          color: (_balances['__total_owed'] ?? 0.0) >= (_balances['__total_owing'] ?? 0.0) 
                              ? Colors.green 
                              : Colors.red,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF5A9C1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            // Show settle up options
                            _showSettleUpDialog();
                          },
                          child: const Text(
                            'Settle Up',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (_balances.entries.where((e) => !e.key.startsWith('__')).isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(),
                            const SizedBox(height: 8),
                            const Text(
                              'Individual Balances',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._balances.entries.where((e) => !e.key.startsWith('__')).map((entry) {
                              final name = entry.key;
                              final balance = entry.value;
                              final isPositive = balance >= 0;
                              
                              // Skip zero balances
                              if (balance == 0) return const SizedBox.shrink();
                              
                              String displayText;
                              if (isPositive) {
                                displayText = '$name owes you ${CurrencyService.formatCurrency(balance.abs(), _selectedCurrency)}';
                              } else {
                                displayText = 'You owe $name ${CurrencyService.formatCurrency(balance.abs(), _selectedCurrency)}';
                              }
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                                      color: isPositive ? Colors.green : Colors.red,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(displayText),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Activities List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(_auth.currentUser?.uid)
                  .collection('activities')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final activities = snapshot.data?.docs ?? [];
                
                if (activities.isEmpty) {
                  return const Center(
                    child: Text(
                      'No activities yet. Create an activity to add transactions!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                // Convert to list of maps with balance info
                List<Map<String, dynamic>> activityList = activities.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  
                  // Calculate balance for this activity
                  double balance = 0;
                  if (data['balances'] != null) {
                    final balances = Map<String, dynamic>.from(data['balances']);
                    if (balances.containsKey('You')) {
                      balance = balances['You'].toDouble();
                    }
                  }
                  
                  data['balance'] = balance;
                  return data;
                }).toList();
                
                // Apply filter
                final filteredActivities = _filterActivities(activityList);
                
                if (filteredActivities.isEmpty) {
                  return Center(
                    child: Text(
                      'No ${_selectedFilter.toLowerCase()} transactions found',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredActivities.length,
                  itemBuilder: (context, index) {
                    final activity = filteredActivities[index];
                    final activityId = activity['id'];
                    final activityName = activity['name'] ?? 'Unnamed Activity';
                    final balance = activity['balance'] ?? 0.0;
                    final hasBalance = balance != 0;
                    
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
                              builder: (context) => ActivityDetailsScreen(
                                activityId: activityId,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFFB19CD9).withOpacity(0.2),
                                child: const Icon(
                                  Icons.group,
                                  color: Color(0xFFB19CD9),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activityName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (hasBalance)
                                      Text(
                                        balance > 0
                                            ? 'You are owed ${CurrencyService.formatCurrency(balance.abs(), _selectedCurrency)}'
                                            : 'You owe ${CurrencyService.formatCurrency(balance.abs(), _selectedCurrency)}',
                                        style: TextStyle(
                                          color: balance > 0 ? Colors.green : Colors.red,
                                          fontSize: 14,
                                        ),
                                      )
                                    else
                                      const Text(
                                        'Tap to view transactions',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFF5A9C1),
        onPressed: () async {
          // Check if user has any activities first
          final activitiesSnapshot = await _firestore
              .collection('users')
              .doc(_auth.currentUser?.uid)
              .collection('activities')
              .limit(1)
              .get();
              
          if (activitiesSnapshot.docs.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Create an activity first before adding expenses'),
              ),
            );
            return;
          }
          
          // Get the first activity to pass to AddExpenseScreen
          final firstActivity = activitiesSnapshot.docs.first;
          final activityId = firstActivity.id;
          final activityName = firstActivity.data()['name'] ?? 'Unnamed Activity';
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddExpenseScreen(
                activityId: activityId,
                activityName: activityName,
              ),
            ),
          ).then((_) {
            // Refresh balances when returning from add expense screen
            _calculateBalances();
          });
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

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
              ..._balances.entries.where((e) => !e.key.startsWith('__') && e.value != 0).map((entry) {
                final name = entry.key;
                final balance = entry.value;
                final isPositive = balance >= 0;
                
                String displayText;
                if (isPositive) {
                  displayText = '$name owes you ${CurrencyService.formatCurrency(balance.abs(), _selectedCurrency)}';
                } else {
                  displayText = 'You owe $name ${CurrencyService.formatCurrency(balance.abs(), _selectedCurrency)}';
                }
                
                return ListTile(
                  title: Text(name),
                  subtitle: Text(
                    displayText,
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showConfirmSettlementDialog(name, balance);
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

  void _showConfirmSettlementDialog(String person, double balance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Settlement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              balance >= 0
                  ? 'Are you sure $person has paid you ${CurrencyService.formatCurrency(balance.abs(), _selectedCurrency)}?'
                  : 'Are you sure you have paid $person ${CurrencyService.formatCurrency(balance.abs(), _selectedCurrency)}?'
            ),
            const SizedBox(height: 16),
            const Text(
              'This will create a settlement transaction and update your balances.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
              Navigator.pop(context);
              _createSettlementTransaction(person, balance);
            },
            child: const Text('Confirm'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createSettlementTransaction(String person, double balance) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Get the activity ID to add the settlement transaction to
        final activitiesSnapshot = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('activities')
            .where('name', isEqualTo: 'Settlements')
            .limit(1)
            .get();
        
        String activityId;
        
        // If no Settlements activity exists, create one
        if (activitiesSnapshot.docs.isEmpty) {
          final newActivityRef = await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('activities')
              .add({
                'name': 'Settlements',
                'description': 'Automatic settlements between friends',
                'date': DateFormat.yMMMd().format(DateTime.now()),
                'members': [
                  {'name': 'You'},
                  {'name': person}
                ],
                'totalAmount': 0.0,
                'balances': {},
              });
          
          activityId = newActivityRef.id;
        } else {
          activityId = activitiesSnapshot.docs.first.id;
          
          // Check if the person is already a member of the Settlements activity
          final activityDoc = activitiesSnapshot.docs.first;
          final members = List<Map<String, dynamic>>.from(activityDoc.data()['members'] ?? []);
          final memberNames = members.map((m) => m['name'] as String).toList();
          
          if (!memberNames.contains(person)) {
            // Add the person to the members list
            members.add({'name': person});
            await _firestore
                .collection('users')
                .doc(currentUser.uid)
                .collection('activities')
                .doc(activityId)
                .update({'members': members});
          }
        }
        
        // Create a settlement transaction
        final isPositive = balance >= 0;
        final settlement = {
          'title': isPositive ? '$person settled debt' : 'You settled debt with $person',
          'amount': balance.abs(),
          'currency': _selectedCurrency,
          'date': DateFormat.yMMMd().format(DateTime.now()),
          'description': 'Settlement transaction',
          'paid_by': isPositive ? person : 'You',
          'split': 'equally',
          'participants': [isPositive ? 'You' : person],
          'is_settlement': true,
        };
        
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('activities')
            .doc(activityId)
            .collection('transactions')
            .add(settlement);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settlement recorded successfully'),
          ),
        );
        
        // Recalculate balances
        await _calculateBalances();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating settlement: $e')),
      );
    }
  }
}

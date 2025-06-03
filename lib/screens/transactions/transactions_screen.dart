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

                // Flatten all transactions from all activities
                List<Map<String, dynamic>> allTransactions = [];
                
                for (var activity in activities) {
                  final activityId = activity.id;
                  final activityName = activity['name'] ?? 'Unnamed Activity';
                  
                  // We'll need to fetch transactions for each activity
                  // This is a placeholder - we'll need to use another approach
                  // to get all transactions across activities
                }
                
                // For now, show activities instead of transactions
                return ListView.builder(
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    final activityId = activity.id;
                    final activityName = activity['name'] ?? 'Unnamed Activity';
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple.withOpacity(0.2),
                          child: Icon(
                            Icons.group,
                            color: Colors.purple,
                          ),
                        ),
                        title: Text(
                          activityName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Tap to view transactions',
                          style: const TextStyle(color: Colors.grey),
                        ),
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
        backgroundColor: Color(0xFFF5A9C1),
        onPressed: () {
          // Navigate directly to activities list to select one
          Navigator.pushNamed(context, '/activities');
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
